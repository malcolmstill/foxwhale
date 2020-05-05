const std = @import("std");
const epoll = @import("epoll.zig");
const Context = @import("wl/context.zig").Context;
const wl = @import("wl/protocols.zig");
const Dispatchable = epoll.Dispatchable;

const MAX_CLIENTS = 256;

var clients: [MAX_CLIENTS]Client = undefined;

pub const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: Dispatchable,
    context: Context,
    display: ?u32,
    seat: ?u32,
    compositor: ?u32,
    subcompositor: ?u32,
    shm: ?u32,
    xdg_wm_base: ?u32,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.context.deinit();
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
            clients[i].context.init(conn.file.handle, &clients[i]);

            if (wl.new_wl_display(&clients[i].context, 1)) |o| {
                clients[i].display = o.id;
            }

            try epoll.addFd(conn.file.handle, &clients[i].dispatchable);

            return &clients[i];
        } else {
            i = i + 1;
            continue;
        }
    }

    return ClientsError.ClientsExhausted;
}

fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!void {
    var client = @fieldParentPtr(Client, "dispatchable", dispatchable);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n\n", .{ client.index });
        client.deinit();
        return;
    }

    try client.context.dispatch();
}

const ClientsError = error {
    ClientsExhausted,
};
