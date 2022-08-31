const std = @import("std");
const mem = std.mem;
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
const Compositor = @import("compositor.zig").Compositor;

pub const Context = WlContext(*Client);
pub const Object = WlContext(*Client).Object;

pub const Client = struct {
    compositor: *Compositor = null,
    alloc: *mem.Allocator,
    connection: std.net.StreamServer.Connection,
    dispatchable: Dispatchable,
    context: WlContext(*Self),
    serial: u32 = 0,
    server_id: u32 = 0xff000000 - 1,

    wl_display: Object,
    wl_registry_id: ?u32 = null,
    wl_data_device_manager_id: ?u32 = null,
    wl_keyboard_id: ?u32 = null,
    wl_output_id: ?u32 = null,
    wl_pointer_id: ?u32 = null,
    wl_seat_id: ?u32 = null,
    wl_compositor_id: ?u32 = null,
    wl_subcompositor_id: ?u32 = null,
    wl_shm_id: ?u32 = null,
    xdg_wm_base_id: ?u32 = null,
    fw_control_id: ?u32 = null,
    zwp_linux_dmabuf_id: ?u32 = null,

    const Self = @This();

    pub fn init(allocator: *mem.Allocator, compositor: *Compositor, conn: std.net.StreamServer.Connection) !*Self {
        const client = try allocator.create(Client);

        client.compositor = compositor;
        client.alloc = allocator;
        client.dispatchable.impl = dispatch;
        client.connection = conn;
        client.context.init(conn.stream.handle, client);

        client.wl_display = prot.new_wl_display(1, &client.context, 0);
        try client.context.register(client.wl_display);

        try epoll.addFd(conn.stream.handle, &client.dispatchable);

        return client;
    }

    pub fn deinit(self: *Self) !void {
        self.context.deinit();

        shm_pool.releaseShmPools(self);
        try buffer.releaseBuffers(self);
        try window.releaseWindows(self);
        try region.releaseRegions(self);
        try positioner.releasePositioners(self);

        epoll.removeFd(self.connection.stream.handle) catch {
            std.debug.warn("Client not removed from epoll: {}\n", .{self.getFd()});
        };

        std.os.close(self.connection.stream.handle);

        // TODO: have caller destroy?
        self.alloc.destroy(self);
    }

    pub fn nextSerial(self: *Self) u32 {
        self.serial += 1;
        return self.serial;
    }

    pub fn nextServerId(self: *Self) u32 {
        self.server_id += 1;
        return self.server_id;
    }

    pub fn getFd(self: *Self) usize {
        return @bitCast(u32, self.connection.stream.handle);
    }
};

fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!void {
    var client = @fieldParentPtr(Client, "dispatchable", dispatchable);

    if (event_type & std.os.linux.EPOLLHUP > 0) {
        std.debug.warn("client {}: hung up.\n", .{client.getFd()});
        try client.deinit();
        // std.debug.warn("client {}: freed.\n", .{client.getFd()});
        return;
    }

    client.context.dispatch() catch |err| {
        if (err == error.ClientSigbusd) {
            std.debug.warn("client {} sigbus'd\n", .{client.getFd()});
            try client.deinit();
        } else {
            if (std.builtin.mode == std.builtin.Mode.Debug) {
                std.debug.warn("DEBUG: client[{}] error: {}\n", .{ client.getFd(), err });
                return err;
            } else {
                std.debug.warn("RELEASE: client[{}] error: {}\n", .{ client.getFd(), err });
                try client.deinit();
            }
        }
    };
}
