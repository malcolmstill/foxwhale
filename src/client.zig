const std = @import("std");
const epoll = @import("epoll.zig");
const Context = @import("wl/context.zig").Context;
const wl = @import("wl/wayland.zig");
const Dispatchable = epoll.Dispatchable;

const MAX_CLIENTS = 256;

var clients: [MAX_CLIENTS]Client = undefined;

const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: Dispatchable,
    ctx: Context,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.ctx.deinit();
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
            std.debug.warn("init context\n", .{});
            clients[i].ctx.init(conn.file.handle);

            var o = wl.new_wl_display(&clients[i].ctx, 1);
            // wl.wl_display_send_delete_id(o, 1);
            // std.debug.warn("tx_buf after send_delete {x}\n", .{clients[i].ctx.tx_buf});
            // var s = [_]u8{0x41, 0x41, 0x41, 0x41, 0x00};
            // wl.wl_display_send_error(o, 1, @enumToInt(wl.wl_display_error.no_memory), s[0..s.len]);
            // std.debug.warn("tx_buf after send_error {x}\n", .{clients[i].ctx.tx_buf});

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

    try client.ctx.dispatch();
}

const ClientsError = error {
    ClientsExhausted,
};
