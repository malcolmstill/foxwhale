
const std = @import("std");
const fs = std.fs;
const ndispatch = @import("dispatchable.zig");
const clients = @import("client.zig");

pub const Display = struct {
    server: std.net.StreamServer,
    dispatchable: ndispatch.Dispatchable,

    const Self = @This();

    pub fn init() !Display {
        var d = Display {
            .dispatchable = ndispatch.Dispatchable {
                .container = undefined,
                .impl = dispatch,
            },
            .server = try socket(),
        };

        // d.dispatchable.container = @ptrToInt(&d);

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

pub fn dispatch(ptr: usize) void {
    var d = @intToPtr(*Display, ptr);
    
    var conn = d.server.accept() catch |err| {
        std.debug.warn("Failed to accept conn\n", .{});
        return;
    };
    
    var client = clients.newClient(conn);
    std.debug.warn("New client {}\n", .{ client });
}