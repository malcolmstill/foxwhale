const std = @import("std");
const fs = std.fs;
const clients = @import("client.zig");
const epoll = @import("epoll.zig");
const implementations = @import("implementations.zig");

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
    var server = @fieldParentPtr(Server, "dispatchable", dispatchable);

    var conn = try server.server.accept();
    errdefer {
        std.os.close(conn.stream.handle);
    }

    var client = try clients.newClient(conn);
    errdefer {
        client.deinit();
    }

    std.debug.warn("\nclient {}: connected.\n", .{client.getIndexOf()});
}
