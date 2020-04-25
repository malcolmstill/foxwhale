const max_clients = 256;

var clients: [max_clients]Client = undefined;

const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: ndispatch.Dispatchable,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.in_use = false;
    }
};

pub fn newClient(conn: std.net.StreamServer.Connection) !*Client {
    var i: usize = 0;
    while (i < max_clients) {
        if (clients[i].in_use) {
            i = i + 1;
            continue;
        } else {
            clients[i].index = i;
            clients[i].in_use = true;
            clients[i].connection = conn;
            clients[i].dispatchable.container = @ptrToInt(&clients[i]);
            clients[i].dispatchable.impl = dispatch;
            return &clients[i];
        }
    }

    return ClientsError.ClientsExhausted;
}

fn dispatch(ptr: usize) void {
    var c = @intToPtr(*Client, ptr);
    std.debug.warn("client dispatch: {}\n", .{ c });
}

const ClientsError = error {
    ClientsExhausted,
};

const std = @import("std");
const ndispatch = @import("dispatchable.zig");