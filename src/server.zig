const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const ServerTargetEvent = @import("subsystem.zig").ServerTargetEvent;
const ServerEvent = @import("subsystem.zig").ServerEvent;
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("protocols.zig").WlObject;
const WlDisplay = @import("protocols.zig").WlDisplay;
const StaticArray = @import("stalloc.zig").StaticArray;

pub const Server = struct {
    alloc: mem.Allocator,
    server: std.net.StreamServer,
    clients: StaticArray(*Client),

    const Self = @This();

    pub fn init(alloc: mem.Allocator) !Server {
        return Server{
            .alloc = alloc,
            .server = try socket(),
            .clients = try StaticArray(*Client).init(alloc, 1024),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.clients.entries) |e| {
            if (e.in_use) {
                const client = e.value;
                self.alloc.destroy(client);
            }
        }
        self.clients.deinit();
        self.server.close();
    }

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        const client = try self.alloc.create(Client);
        client.* = Client{
            .connection = conn,
            .wl_display = WlDisplay.init(1, client, 0, 0),
            .context = Context.init(conn.stream.handle),
        };

        try client.context.register(WlObject{ .wl_display = client.wl_display });

        const client_ptr = try self.clients.create();
        client_ptr.* = client;

        return client;
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
                .server = ServerTargetEvent{
                    .target = self.server,
                    .event = ServerEvent{
                        .client_connected = conn,
                    },
                },
            };
        }
    };
};

pub fn socket() !std.net.StreamServer {
    _ = std.os.unlink("/run/user/1000/wayland-1") catch {};
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-1");

    var server = std.net.StreamServer.init(.{});
    try server.listen(addr);

    return server;
}
