const std = @import("std");
const prot = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;
const Window = @import("window.zig").Window;

fn commit(context: *Context, wl_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);

    if (window.wl_buffer_id) |wl_buffer_id| {
        if (context.get(wl_buffer_id)) |wl_buffer| {
            try prot.wl_buffer_send_release(wl_buffer.*);
        }
    }

    if (std.builtin.mode == std.builtin.Mode.Debug) {
        std.time.sleep(@divFloor(10000000000, 60));
    }

    while(window.callbacks.readItem()) |callback_id| {
        if (context.get(callback_id)) |callback| {
            try prot.wl_callback_send_done(callback.*, @intCast(u32, std.time.timestamp()));
            try context.unregister(callback.*);
            try prot.wl_display_send_delete_id(window.client.display, callback_id);
        } else {
            return error.CallbackIdNotFound;
        }
    } else |err| {}
}

fn damage(context: *Context, wl_surface: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    // std.debug.warn("damage does nothing\n", .{});
}

fn attach(context: *Context, wl_surface: Object, wl_buffer: Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    // window.pending = true;
    window.wl_buffer_id = wl_buffer.id;
}

fn frame(context: *Context, wl_surface: Object, new_id: u32) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    try window.callbacks.writeItem(new_id);

    var callback = prot.new_wl_callback(new_id, context, 0);
    try context.register(callback);
}

fn destroy(context: *Context, wl_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    // TODO: what about subsurfaces / popups?
    window.deinit();

    try prot.wl_display_send_delete_id(context.client.display, wl_surface.id);
    try context.unregister(wl_surface);
}

pub fn init() void {
    prot.WL_SURFACE.commit = commit;
    prot.WL_SURFACE.damage = damage;
    prot.WL_SURFACE.attach = attach;
    prot.WL_SURFACE.frame = frame;
    prot.WL_SURFACE.destroy = destroy;
}
