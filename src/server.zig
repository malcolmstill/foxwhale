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
    clients: std.TailQueue(Client),

    const Node = std.TailQueue(Client).Node;

    const Self = @This();

    pub fn init(alloc: mem.Allocator) !Server {
        return Server{
            .alloc = alloc,
            .server = try socket(),
            .clients = std.TailQueue(Client){},
        };
    }

    pub fn deinit(self: *Self) void {
        while (self.clients.pop()) |node| {
            self.removeClient(&node.data);
        }

        self.server.close();
    }

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        const node = try self.alloc.create(Node);
        const client: *Client = &node.data;

        client.* = Client{
            .conn = conn,
            .wl_display = WlDisplay.init(1, client, 0, 0),
            .context = Context.init(conn.stream.handle),
        };

        try client.context.register(WlObject{ .wl_display = client.wl_display });

        self.clients.append(node);

        return client;
    }

    pub fn removeClient(self: *Self, client: *Client) void {
        const node: *Node = @fieldParentPtr(Node, "data", client);
        self.clients.remove(node);
        self.alloc.destroy(node);
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
