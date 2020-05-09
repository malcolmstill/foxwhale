const std = @import("std");
const epoll = @import("epoll.zig");
const Object = @import("wl/context.zig").Object;
const Context = @import("wl/context.zig").Context;
const prot = @import("wl/protocols.zig");
const shm_pool = @import("shm_pool.zig");
const shm_buffer = @import("shm_buffer.zig");
const window = @import("window.zig");
const region = @import("region.zig");
const Dispatchable = epoll.Dispatchable;

const MAX_CLIENTS = 256;

var CLIENTS: [MAX_CLIENTS]Client = undefined;

pub const Client = struct {
    index: usize,
    in_use: bool,
    connection: std.net.StreamServer.Connection,
    dispatchable: Dispatchable,
    context: Context,
    serial: u32 = 0,
    wl_display: Object,
    wl_output_id: ?u32,
    wl_seat_id: ?u32,
    wl_compositor_id: ?u32,
    wl_subcompositor_id: ?u32,
    wl_shm_id: ?u32,
    xdg_wm_base_id: ?u32,

    const Self = @This();

    pub fn deinit(self: *Self) !void {
        self.context.deinit();
        self.in_use = false;

        shm_pool.releaseShmPools(self);
        shm_buffer.releaseShmBuffers(self);
        try window.releaseWindows(self);
        try region.releaseRegions(self);

        epoll.removeFd(self.connection.file.handle) catch |err| {
            std.debug.warn("Client not removed from epoll: {}\n", .{ self.index });
        };

        std.os.close(self.connection.file.handle);
    }

    pub fn nextSerial(self: *Self) u32 {
        self.serial += 1;
        return self.serial;
    }
};

pub fn newClient(conn: std.net.StreamServer.Connection) !*Client {
    var i: usize = 0;
    while (i < MAX_CLIENTS) {
        var client: *Client = &CLIENTS[i];
        if (client.in_use == false) {
            client.index = i;
            client.dispatchable.impl = dispatch;
            client.connection = conn;
            client.in_use = true;
            client.context.init(conn.file.handle, client);

            client.wl_display = prot.new_wl_display(1, &client.context, 0);
            try client.context.register(client.wl_display);

            try epoll.addFd(conn.file.handle, &client.dispatchable);

            return client;
        } else {
            i = i + 1;
            continue;
        }
    }

    return error.ClientsExhausted;
}

fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!void {
    var client = @fieldParentPtr(Client, "dispatchable", dispatchable);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n", .{ client.index });
        try client.deinit();
        std.debug.warn("client {}: freed.\n", .{ client.index });
        return;
    }

    client.context.dispatch() catch |err| {
        if (err == error.ClientSigbusd) {
            std.debug.warn("client {} sigbus'd\n", .{client.index});
            try client.deinit();
        } else {
            // TODO: if we're in debug mode return error
            //       if we're in release mode kill the client
            return err;
        }
    };
}