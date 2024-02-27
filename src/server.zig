const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Client = @import("client.zig").Client;
const Wire = @import("wl/wire.zig").Wire;

const wl = @import("client.zig").wl;

const Window = @import("resource/window.zig").Window;
const Buffer = @import("resource/buffer.zig").Buffer;
const Region = @import("resource/region.zig").Region;
const Positioner = @import("resource/positioner.zig").Positioner;
const ShmPool = @import("resource/shm_pool.zig").ShmPool;
const Output = @import("resource/output.zig").Output;
const IterablePool = @import("datastructures/iterable_pool.zig").IterablePool;
const SubsetPool = @import("datastructures/subset_pool.zig").SubsetPool;
const BackendOutput = @import("backend/backend.zig").BackendOutput;
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;
const xkbcommon = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;
const View = @import("view.zig").View;

const log = std.log.scoped(.server);

// pub const ResourceType = enum(u8) {
//     window,
//     region,
//     buffer,
//     shm_pool,
//     output,
//     none,
// };

// pub const Resource = union(ResourceType) {
//     window: *Window,
//     region: *Region,
//     buffer: *Buffer,
//     shm_pool: *ShmPool,
//     output: *Output,
//     none: void,
// };

// pub const ResourceObject = struct {
//     object: wl.WlObject,
//     resource: Resource,
// };

pub const Server = struct {
    alloc: mem.Allocator,
    server: std.net.StreamServer,
    // per-server resources:
    clients: IterablePool(Client, u8),
    outputs: IterablePool(Output, u5),
    // per-client resources:
    windows: SubsetPool(Window, u16),
    regions: SubsetPool(Region, u16),
    positioners: SubsetPool(Positioner, u16),
    buffers: SubsetPool(Buffer, u16),
    shm_pools: SubsetPool(ShmPool, u16),
    objects: SubsetPool(wl.WlObject, u16),

    move: ?Move = null,
    resize: ?Resize = null,

    current_view: ?*View = null,

    pointer_x: f64 = 0.0,
    pointer_y: f64 = 0.0,

    output_base: u32 = 1000,

    xkb: ?Xkb = null,

    const ClientNode = std.TailQueue(Client).Node;
    const Self = @This();

    pub const TargetEvent = struct {
        server: *Server,
        event: ServerEvent,
    };

    pub const EventType = enum {
        client_connected,
    };

    pub const ServerEvent = union(EventType) {
        client_connected: std.net.StreamServer.Connection,
    };

    pub fn init(alloc: mem.Allocator) !Server {
        return Server{
            .alloc = alloc,
            .server = try socket(),
            .clients = try IterablePool(Client, u8).init(alloc, 255),
            .outputs = try IterablePool(Output, u5).init(alloc, 31),
            .windows = try SubsetPool(Window, u16).init(alloc, 1024),
            .regions = try SubsetPool(Region, u16).init(alloc, 1024),
            .positioners = try SubsetPool(Positioner, u16).init(alloc, 1024),
            .buffers = try SubsetPool(Buffer, u16).init(alloc, 1024),
            .shm_pools = try SubsetPool(ShmPool, u16).init(alloc, 1024),
            .objects = try SubsetPool(wl.WlObject, u16).init(alloc, 16384),

            .xkb = try xkbcommon.init(),
        };
    }

    pub fn deinit(server: *Self) void {
        server.server.close();

        server.clients.deinit();
        server.windows.deinit();
        server.regions.deinit();
        server.positioners.deinit();
        server.buffers.deinit();
        server.shm_pools.deinit();

        server.objects.deinit();
    }

    pub fn usage(server: *Self) void {
        std.debug.print("\n- Usage -------\n", .{});
        std.debug.print("  clients: {}   \n", .{server.clients.pool.count});
        std.debug.print("  outputs: {}   \n", .{server.outputs.pool.count});
        std.debug.print("  windows: {}   \n", .{server.windows.pool.count});
        std.debug.print("  regions: {}   \n", .{server.regions.pool.count});
        std.debug.print("  buffers: {}   \n", .{server.buffers.pool.count});
        std.debug.print("  shm_pools: {} \n", .{server.shm_pools.pool.count});
        std.debug.print("  objects: {}   \n", .{server.objects.pool.count});
        std.debug.print("---------------\n", .{});
    }

    pub fn addClient(server: *Self, conn: std.net.StreamServer.Connection) !*Client {
        var client = try server.clients.createPtr();
        errdefer server.clients.destroy(client);

        const wl_display = wl.WlDisplay.init(1, &client.wire, 0, null);
        client.* = Client.init(server.alloc, server, conn, wl_display);
        try client.register(.{ .wl_display = wl_display });

        return client;
    }

    pub fn removeClient(server: *Self, client: *Client) void {
        client.deinit();
        server.clients.destroy(client);
    }

    /// Initialise a new backend of the given type.
    ///
    /// If this is the first output, the current view will be the first view
    /// of the output.
    pub fn addOutput(server: *Self, backend_output: *BackendOutput) !*Output {
        const output = try Output.init(server, backend_output);
        const output_ptr = try server.outputs.create(output);

        server.current_view = &output_ptr.views[0];

        return output_ptr;
    }

    pub fn mouseClick(server: *Self, button: u32, action: u32) !void {
        // log.info("mouseClick: button={} action={}", .{ button, action });
        if (server.move) |_| {
            // Mouse raise cancels move
            if (action == 0) {
                server.move = null;
            }
        }

        if (server.resize) |_| {
            // Mouse raise cancels resize
            if (action == 0) {
                server.resize = null;
            }
        }

        const view = server.current_view orelse return;

        try view.mouseClick(button, action);
    }

    pub fn mouseMove(server: *Self, dx: f64, dy: f64) !void {
        const view = server.current_view orelse return;
        const width: f64 = @floatFromInt(view.backend_output.getWidth());
        const height: f64 = @floatFromInt(view.backend_output.getHeight());

        server.pointer_x = server.pointer_x + dx;
        server.pointer_y = server.pointer_y + dy;

        if (server.pointer_x < 0) {
            server.pointer_x = 0;
        }

        if (server.pointer_x > width) {
            server.pointer_x = width;
        }

        if (server.pointer_y < 0) {
            server.pointer_y = 0;
        }

        if (server.pointer_y > height) {
            server.pointer_y = height;
        }

        if (server.move) |move| {
            const new_window_x = move.window_x + @as(i32, @intFromFloat(server.pointer_x - move.pointer_x));
            const new_window_y = move.window_y + @as(i32, @intFromFloat(server.pointer_y - move.pointer_y));
            move.window.current().x = new_window_x;
            move.window.pending().x = new_window_x;
            move.window.current().y = new_window_y;
            move.window.pending().y = new_window_y;
            return;
        }

        if (server.resize) |resize| {
            try resize.resize(server.pointer_x, server.pointer_y);
            return;
        }

        try view.updatePointer(server.pointer_x, server.pointer_y);
    }

    pub fn iterator(server: *Server) SubsystemIterator {
        return SubsystemIterator{ .server = Iterator.init(server) };
    }

    pub const Iterator = struct {
        server: *Server,
        accepted: bool = false,

        pub fn init(server: *Server) Iterator {
            return Iterator{
                .server = server,
            };
        }

        pub fn next(it: *Iterator, _: u32) !?Event {
            if (it.accepted) return null;

            const conn = try it.server.server.accept();

            it.accepted = true;

            return Event{
                .server = Server.TargetEvent{
                    .server = it.server,
                    .event = ServerEvent{
                        .client_connected = conn,
                    },
                },
            };
        }
    };
};

fn socket() !std.net.StreamServer {
    _ = std.os.unlink("/run/user/1000/wayland-1") catch {};
    const addr = try std.net.Address.initUnix("/run/user/1000/wayland-1");

    var server = std.net.StreamServer.init(.{});
    try server.listen(addr);

    return server;
}
