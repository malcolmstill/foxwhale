const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("wl/protocols.zig").WlObject;
const WlDisplay = @import("wl/protocols.zig").WlDisplay;
const StaticArray = @import("stalloc.zig").StaticArray;
const Window = @import("window.zig").Window;
const Buffer = @import("buffer.zig").Buffer;
const Region = @import("region.zig").Region;
const ShmPool = @import("shm_pool.zig").ShmPool;
const Pool = @import("pool.zig").Pool;
const PoolIterable = @import("pool_iterable.zig").PoolIterable;

pub const ResourceType = enum(u8) {
    window,
    region,
    buffer,
    shm_pool,
    none,
};

pub const Resource = union(ResourceType) {
    window: *Window,
    region: *Region,
    buffer: *Buffer,
    shm_pool: *ShmPool,
    none: void,
};

pub const ResourceObject = struct {
    object: WlObject,
    resource: Resource,
};

pub const Server = struct {
    alloc: mem.Allocator,
    server: std.net.StreamServer,
    // resources:
    clients: Pool(Client, u8),
    windows: PoolIterable(Window, u16),
    regions: PoolIterable(Region, u16),
    buffers: PoolIterable(Buffer, u16),
    shm_pools: PoolIterable(ShmPool, u16),
    objects: PoolIterable(ResourceObject, u16),

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
            .clients = try Pool(Client, u8).init(alloc, 255),
            .windows = try PoolIterable(Window, u16).init(alloc, 1024),
            .regions = try PoolIterable(Region, u16).init(alloc, 1024),
            .buffers = try PoolIterable(Buffer, u16).init(alloc, 1024),
            .shm_pools = try PoolIterable(ShmPool, u16).init(alloc, 1024),
            .objects = try PoolIterable(ResourceObject, u16).init(alloc, 16384),
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

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        var client = try self.clients.createPtr();
        errdefer self.clients.destroy(client);

        const wl_display = WlDisplay.init(1, &client.context, 0);
        client.* = Client.init(self.alloc, self, conn, wl_display);
        try client.link(.{ .wl_display = wl_display }, .none);

        return client;
    }

    pub fn removeClient(self: *Self, client: *Client) void {
        client.deinit();
        self.clients.destroy(client);
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
