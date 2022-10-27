const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("protocols.zig").WlObject;
const WlDisplay = @import("protocols.zig").WlDisplay;
const WlSurface = @import("protocols.zig").WlSurface;
const WlRegion = @import("protocols.zig").WlRegion;
const StaticArray = @import("stalloc.zig").StaticArray;
const Window = @import("window.zig").Window;
const Buffer = @import("buffer.zig").Buffer;
const Region = @import("region.zig").Region;
const ShmPool = @import("shm_pool.zig").ShmPool;
const Pool = @import("pool.zig").Pool;

pub const Server = struct {
    alloc: mem.Allocator,
    server: std.net.StreamServer,
    // resources:
    clients: Pool(Client, u8),
    windows: Pool(Window, u16),
    regions: Pool(Region, u16),
    buffers: Pool(Buffer, u16),
    shm_pools: Pool(ShmPool, u16),

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
            .windows = try Pool(Window, u16).init(alloc, 1024),
            .regions = try Pool(Region, u16).init(alloc, 1024),
            .buffers = try Pool(Buffer, u16).init(alloc, 1024),
            .shm_pools = try Pool(ShmPool, u16).init(alloc, 1024),
        };
    }

    pub fn deinit(self: *Self) void {
        self.server.close();

        self.clients.deinit();
        self.windows.deinit();
        self.regions.deinit();
        self.buffers.deinit();
        self.shm_pools.deinit();
    }

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        const client: *Client = try self.clients.createPtr();
        const wl_display = WlDisplay.init(1, &client.context, 0);

        client.* = Client.init(self.alloc, self, conn, wl_display);

        try client.context.register(WlObject{ .wl_display = wl_display });

        return client;
    }

    pub fn removeClient(self: *Self, client: *Client) void {
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
