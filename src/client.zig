const MAX_CLIENTS = 256;

var clients: [MAX_CLIENTS]Client = undefined;

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
    comptime {
        var i: usize = 0;
        while (i < MAX_CLIENTS) {
            clients[i].index = i;
            clients[i].dispatchable.container = @ptrToInt(&clients[i]);
            clients[i].dispatchable.impl = dispatch;
            i = i + 1;
        }
    }

    var i: usize = 0;
    while (i < MAX_CLIENTS) {
        if (clients[i].in_use == false) {
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

fn dispatch(ptr: usize) void {
    var c = @intToPtr(*Client, ptr);
    std.debug.warn("client dispatch: {}\n", .{ c });
}

const ClientsError = error {
    ClientsExhausted,
};

const std = @import("std");
const ndispatch = @import("dispatchable.zig");