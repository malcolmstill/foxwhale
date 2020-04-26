const std = @import("std");
const epoll = @import("epoll.zig");

const MAX_CLIENTS = 256;

var clients: [MAX_CLIENTS]Client = undefined;

const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: epoll.Dispatchable,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.in_use = false;

        epoll.removeFd(self.connection.file.handle) catch |err| {
            std.debug.warn("Client not removed from epoll: {}\n", .{ self.index });
        };

        std.os.close(self.connection.file.handle);
    }
};

pub fn newClient(conn: std.net.StreamServer.Connection) !*Client {
    var i: usize = 0;
    while (i < MAX_CLIENTS) {
        if (clients[i].in_use == false) {
            clients[i].index = i;
            clients[i].dispatchable.container = @ptrToInt(&clients[i]);
            clients[i].dispatchable.impl = dispatch;
            clients[i].connection = conn;
            clients[i].in_use = true;
            return &clients[i];
        } else {
            i = i + 1;
            continue;
        }
    }

    return ClientsError.ClientsExhausted;
}

var buffer: [1024]u8 = undefined;

fn dispatch(ptr: usize, event_type: usize) void {
    var c = @intToPtr(*Client, ptr);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n", .{ c.index });
        c.deinit();
        return;
    }

    var n = std.os.read(c.connection.file.handle, buffer[0..buffer.len]);
    std.debug.warn("client {}: read {} bytes.\n", .{ c.index, n });
}

const ClientsError = error {
    ClientsExhausted,
};
