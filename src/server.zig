const std = @import("std");
const fs = std.fs;
const clients = @import("client.zig");
const epoll = @import("epoll.zig");
const implementations = @import("implementations.zig");
const Client = @import("client.zig").Client;
const Compositor = @import("compositor.zig").Compositor;

pub const Server = struct {
    server: std.net.StreamServer,
    dispatchable: epoll.Dispatchable,

    const Self = @This();

    pub fn init() !Server {
        implementations.init();

        return Server{
            .dispatchable = epoll.Dispatchable{
                .impl = dispatch,
            },
            .server = try socket(),
        };
    }

    pub fn addToEpoll(self: *Self) !void {
        try epoll.addFd(self.server.sockfd.?, &self.dispatchable);
    }

    pub fn deinit(self: *Self) void {
        self.server.close();
    }
};

pub fn socket() !std.net.StreamServer {
    var x = std.os.unlink("/run/user/1000/wayland-0");
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-0");

    var server = std.net.StreamServer.init(.{});
    try server.listen(addr);

    return server;
}

pub fn dispatch(dispatchable: *epoll.Dispatchable, event_type: usize) anyerror!void {
    const srv = @fieldParentPtr(Server, "dispatchable", dispatchable);
    const compositor = @fieldParentPtr(Compositor, "server", srv);

    var conn = try srv.server.accept();
    errdefer {
        std.os.close(conn.stream.handle);
    }

    const client = try Client.init(compositor.alloc, conn);
    errdefer {
        client.deinit() catch |err| {};
    }

    try compositor.clients.append(client);

    std.debug.warn("\nclient {}: connected.\n", .{client.getFd()});
}
