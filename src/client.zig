const std = @import("std");
const epoll = @import("epoll.zig");
const context = @import("context.zig");

const MAX_CLIENTS = 256;

var clients: [MAX_CLIENTS]Client = undefined;

const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: epoll.Dispatchable,
    ctx: context.Context,

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
            clients[i].dispatchable.impl = dispatch;
            clients[i].connection = conn;
            clients[i].in_use = true;

            try epoll.addFd(conn.file.handle, &clients[i].dispatchable);

            return &clients[i];
        } else {
            i = i + 1;
            continue;
        }
    }

    return ClientsError.ClientsExhausted;
}

fn dispatch(dispatchable: *epoll.Dispatchable, event_type: usize) anyerror!void {
    var c = @fieldParentPtr(Client, "dispatchable", dispatchable);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n\n", .{ c.index });
        c.deinit();
        return;
    }

    try c.ctx.dispatch(c.connection.file.handle);
}

const ClientsError = error {
    ClientsExhausted,
};
