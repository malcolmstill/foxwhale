
const std = @import("std");
const fs = std.fs;
const clients = @import("client.zig");
const epoll = @import("epoll.zig");

pub const Display = struct {
    server: std.net.StreamServer,
    dispatchable: epoll.Dispatchable,

    const Self = @This();

    pub fn init() !Display {
        var d = Display {
            .dispatchable = epoll.Dispatchable {
                .container = undefined,
                .impl = dispatch,
            },
            .server = try socket(),
        };

        return d;
    }

    pub fn initDispatch(self: *Self) void {
        self.dispatchable.container = @ptrToInt(self);
    }
};

pub fn socket() !std.net.StreamServer {
    var x = std.os.unlink("/run/user/1000/wayland-0");
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-0");
    
    var l = std.net.StreamServer.init(.{});
    try l.listen(addr);

    return l;
}

pub fn dispatch(ptr: usize, event_type: usize) void {
    var d = @intToPtr(*Display, ptr);
    
    var conn = d.server.accept() catch |err| {
        std.debug.warn("Failed to accept conn for client\n", .{});
        return;
    };
    
    var client = clients.newClient(conn) catch |err| {
        std.debug.warn("Failed to allocate client\n", .{});
        return;
    };

    std.debug.warn("client {}: connected.\n", .{ client.index });
    epoll.addFd(client.connection.file.handle, &client.dispatchable) catch |err| {
        std.debug.warn("Failed to add client to epoll\n", .{});
        client.deinit();
        return;
    };
}