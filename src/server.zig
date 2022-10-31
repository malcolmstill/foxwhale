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
const ShmPool = @import("resource/shm_pool.zig").ShmPool;
const Output = @import("resource/output.zig").Output;
const IterablePool = @import("datastructures/iterable_pool.zig").IterablePool;
const SubsetPool = @import("datastructures/subset_pool.zig").SubsetPool;
const BackendOutput = @import("backend/backend.zig").BackendOutput;
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;
const xkbcommon = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;

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
    buffers: SubsetPool(Buffer, u16),
    shm_pools: SubsetPool(ShmPool, u16),
    objects: SubsetPool(wl.WlObject, u16),

    move: ?Move = null,
    resize: ?Resize = null,

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
            .buffers = try SubsetPool(Buffer, u16).init(alloc, 1024),
            .shm_pools = try SubsetPool(ShmPool, u16).init(alloc, 1024),
            .objects = try SubsetPool(wl.WlObject, u16).init(alloc, 16384),

            .xkb = try xkbcommon.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.server.close();

        self.clients.deinit();
        self.windows.deinit();
        self.regions.deinit();
        self.buffers.deinit();
        self.shm_pools.deinit();

        self.objects.deinit();
    }

    pub fn usage(self: *Self) void {
        std.debug.print("\n- Usage -------\n", .{});
        std.debug.print("  clients: {}   \n", .{self.clients.pool.count});
        std.debug.print("  outputs: {}   \n", .{self.outputs.pool.count});
        std.debug.print("  windows: {}   \n", .{self.windows.pool.count});
        std.debug.print("  regions: {}   \n", .{self.regions.pool.count});
        std.debug.print("  buffers: {}   \n", .{self.buffers.pool.count});
        std.debug.print("  shm_pools: {} \n", .{self.shm_pools.pool.count});
        std.debug.print("  objects: {}   \n", .{self.objects.pool.count});
        std.debug.print("---------------\n", .{});
    }

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        var client = try self.clients.createPtr();
        errdefer self.clients.destroy(client);

        const wl_display = wl.WlDisplay.init(1, &client.wire, 0, null);
        client.* = Client.init(self.alloc, self, conn, wl_display);
        try client.register(.{ .wl_display = wl_display });

        return client;
    }

    pub fn removeClient(self: *Self, client: *Client) void {
        client.deinit();
        self.clients.destroy(client);
    }

    pub fn addOutput(self: *Self, backend_output: *BackendOutput) !*Output {
        return self.outputs.create(try Output.init(self, backend_output));
    }

    pub fn iterator(self: *Server) SubsystemIterator {
        return SubsystemIterator{ .server = Iterator.init(self) };
    }

    pub const Iterator = struct {
        server: *Server,
        accepted: bool = false,

        pub fn init(server: *Server) Iterator {
            return Iterator{
                .server = server,
            };
        }

        pub fn next(self: *Iterator, _: u32) !?Event {
            if (self.accepted) return null;

            var conn = try self.server.server.accept();

            self.accepted = true;

            return Event{
                .server = Server.TargetEvent{
                    .server = self.server,
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
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-1");

    var server = std.net.StreamServer.init(.{});
    try server.listen(addr);

    return server;
}
