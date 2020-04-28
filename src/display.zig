
const std = @import("std");
const fs = std.fs;
const clients = @import("client.zig");
const epoll = @import("epoll.zig");

pub const Display = struct {
    server: std.net.StreamServer,
    dispatchable: epoll.Dispatchable,

    const Self = @This();

    pub fn init() !Display {
        return Display {
            .dispatchable = epoll.Dispatchable {
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
    var display = @fieldParentPtr(Display, "dispatchable", dispatchable);
    
    var conn = try display.server.accept();
    errdefer { std.os.close(conn.file.handle); }
    
    var client = try clients.newClient(conn);
    errdefer { client.deinit(); }

    std.debug.warn("client {}: connected.\n", .{ client.index });
}