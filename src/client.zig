const std = @import("std");
const epoll = @import("epoll.zig");
const WlContext = @import("wl/context.zig").Context;
const prot = @import("protocols.zig");
const shm_pool = @import("shm_pool.zig");
const shm_buffer = @import("shm_buffer.zig");
const window = @import("window.zig");
const region = @import("region.zig");
const positioner = @import("positioner.zig");
const buffer = @import("buffer.zig");
const Dispatchable = epoll.Dispatchable;
const Stalloc = @import("stalloc.zig").Stalloc;

pub var CLIENTS: Stalloc(void, Client, 256) = undefined;

pub const Context = WlContext(*Client);
pub const Object = WlContext(*Client).Object;

pub const Client = struct {
    connection: std.net.StreamServer.Connection,
    dispatchable: Dispatchable,
    context: WlContext(*Self),
    serial: u32 = 0,
    server_id: u32 = 0,

    wl_display: Object,
    wl_registry_id: ?u32,
    wl_data_device_manager_id: ?u32,
    wl_keyboard_id: ?u32,
    wl_output_id: ?u32,
    wl_pointer_id: ?u32,
    wl_seat_id: ?u32,
    wl_compositor_id: ?u32,
    wl_subcompositor_id: ?u32,
    wl_shm_id: ?u32,
    xdg_wm_base_id: ?u32,
    fw_control_id: ?u32,
    zwp_linux_dmabuf_id: ?u32,

    const Self = @This();

    pub fn deinit(self: *Self) !void {
        var freed_index = CLIENTS.deinit(self);
        self.context.deinit();

        self.wl_registry_id = null;
        self.wl_data_device_manager_id = null;
        self.wl_keyboard_id = null;
        self.wl_output_id = null;
        self.wl_pointer_id = null;
        self.wl_seat_id = null;
        self.wl_compositor_id = null;
        self.wl_subcompositor_id = null;
        self.wl_shm_id = null;
        self.xdg_wm_base_id = null;
        self.fw_control_id = null;
        self.zwp_linux_dmabuf_id = null;

        shm_pool.releaseShmPools(self);
        try buffer.releaseBuffers(self);
        try window.releaseWindows(self);
        try region.releaseRegions(self);
        try positioner.releasePositioners(self);

        epoll.removeFd(self.connection.file.handle) catch |err| {
            std.debug.warn("Client not removed from epoll: {}\n", .{ self.getIndexOf() });
        };

        std.os.close(self.connection.file.handle);
    }

    pub fn nextSerial(self: *Self) u32 {
        self.serial += 1;
        return self.serial;
    }

    pub fn nextServerId(self: *Self) u32 {
        self.server_id += 1;
        return self.server_id;
    }

    pub fn getIndexOf(self: *Self) usize {
        return CLIENTS.getIndexOf(self);
    }
};

pub fn newClient(conn: std.net.StreamServer.Connection) !*Client {
    var client: *Client = try CLIENTS.new(undefined);

    client.dispatchable.impl = dispatch;
    client.connection = conn;
    client.context.init(conn.file.handle, client);
    client.server_id = 0xff000000 - 1;

    client.wl_display = prot.new_wl_display(1, &client.context, 0);
    try client.context.register(client.wl_display);

    try epoll.addFd(conn.file.handle, &client.dispatchable);

    return client;
}

fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!void {
    var client = @fieldParentPtr(Client, "dispatchable", dispatchable);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n", .{ client.getIndexOf() });
        try client.deinit();
        std.debug.warn("client {}: freed.\n", .{ client.getIndexOf() });
        return;
    }

    client.context.dispatch() catch |err| {
        if (err == error.ClientSigbusd) {
            std.debug.warn("client {} sigbus'd\n", .{client.getIndexOf()});
            try client.deinit();
        } else {
            if (std.builtin.mode == std.builtin.Mode.Debug) {
                std.debug.warn("DEBUG: client[{}] error: {}\n", .{client.getIndexOf(), err});
                return err;
            } else {
                std.debug.warn("RELEASE: client[{}] error: {}\n", .{client.getIndexOf(), err});
                try client.deinit();
            }
        }
    };
}