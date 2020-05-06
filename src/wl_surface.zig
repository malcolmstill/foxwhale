const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;
const Window = @import("window.zig").Window;

pub fn init() void {    
    wl.WL_SURFACE.commit = commit;
    wl.WL_SURFACE.damage = damage;
    wl.WL_SURFACE.attach = attach;
    wl.WL_SURFACE.frame = frame;
}

fn commit(context: *Context, surface: Object) anyerror!void {
    var window = @intToPtr(*Window, surface.container);

    if (window.wl_buffer) |buffer_id| {
        if (surface.context.get(buffer_id)) |buffer| {
            try wl.wl_buffer_send_release(buffer.*);
        }
    }

    while(window.callbacks.readItem()) |callback_id| {
        if (surface.context.get(callback_id)) |callback| {
            try wl.wl_callback_send_done(callback.*, 1000);
            try surface.context.unregister(callback.*);
            try wl.wl_display_send_delete_id(window.client.display, callback_id);
        } else {
            return error.CallbackIdNotFound;
        }
    } else |err| {}
}

fn damage(context: *Context, surface: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    std.debug.warn("damage does nothing\n", .{});
}

fn attach(context: *Context, surface: Object, buffer: Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, surface.container);
    // window.pending = true;
    window.wl_buffer = buffer.id;
}

fn frame(context: *Context, surface: Object, new_id: u32) anyerror!void {
    var window = @alignCast(@alignOf(Window), @intToPtr(*Window, surface.container));
    try window.callbacks.writeItem(new_id);

    var callback = wl.new_wl_callback(new_id, context, 0);
    try context.register(callback);
}