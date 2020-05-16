const std = @import("std");
const linux = std.os.linux;
const prot = @import("protocols.zig");
const renderer = @import("renderer.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;
const Client = @import("client.zig").Client;
const ShmBuffer = @import("shm_buffer.zig").ShmBuffer;
const Window = @import("window.zig").Window;

fn commit(context: *Context, wl_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);

    if (window.wl_buffer_id) |wl_buffer_id| {
        if (context.get(wl_buffer_id)) |wl_buffer| {
            var buffer = @intToPtr(*ShmBuffer, wl_buffer.container);
            buffer.beginAccess();

            if (window.texture) |texture| {
                window.texture = null;
                try renderer.releaseTexture(texture);
            }

            window.width = buffer.width;
            window.height = buffer.height;
            window.texture = try buffer.makeTexture();

            try buffer.endAccess();
            try prot.wl_buffer_send_release(wl_buffer.*);
        }
    }

    while(window.callbacks.readItem()) |wl_callback_id| {
        if (context.get(wl_callback_id)) |wl_callback| {
            try prot.wl_callback_send_done(wl_callback.*, @truncate(u32, std.time.milliTimestamp()));
            try context.unregister(wl_callback.*);
            try prot.wl_display_send_delete_id(context.client.wl_display, wl_callback_id);
        } else {
            return error.CallbackIdNotFound;
        }
    } else |err| {}
}

fn set_buffer_scale(context: *Context, wl_surface: Object, scale: i32) anyerror!void {
    var pending = @intToPtr(*Window, wl_surface.container).pending();
    pending.scale = scale;
}

fn damage(context: *Context, wl_surface: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    // std.debug.warn("damage does nothing\n", .{});
}

fn attach(context: *Context, wl_surface: Object, optional_wl_buffer: ?Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    // window.pending = true;
    if (optional_wl_buffer) |wl_buffer| {
        window.wl_buffer_id = wl_buffer.id;
    } else {
        window.wl_buffer_id = null;
    }
}

fn frame(context: *Context, wl_surface: Object, new_id: u32) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    try window.callbacks.writeItem(new_id);

    var callback = prot.new_wl_callback(new_id, context, 0);
    try context.register(callback);
}

// TODO: Should we store a *Region instead of a wl_region id?
fn set_opaque_region(context: *Context, wl_surface: Object, optional_wl_region: ?Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    if (optional_wl_region) |wl_region| {
        window.pending().opaque_region_id = wl_region.id;
    } else {
        window.pending().opaque_region_id = null;
    }
}

// TODO: Should we store a *Region instead of a wl_region id?
fn set_input_region(context: *Context, wl_surface: Object, optional_wl_region: ?Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    if (optional_wl_region) |wl_region| {
        window.pending().input_region_id = wl_region.id;
    } else {
        window.pending().input_region_id = null;
    }
}

fn destroy(context: *Context, wl_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    // TODO: what about subsurfaces / popups?
    try window.deinit();

    try prot.wl_display_send_delete_id(context.client.wl_display, wl_surface.id);
    try context.unregister(wl_surface);
}

pub fn init() void {
    prot.WL_SURFACE.set_buffer_scale = set_buffer_scale;
    prot.WL_SURFACE.commit = commit;
    prot.WL_SURFACE.damage = damage;
    prot.WL_SURFACE.attach = attach;
    prot.WL_SURFACE.frame = frame;
    prot.WL_SURFACE.set_opaque_region = set_opaque_region;
    prot.WL_SURFACE.set_input_region = set_input_region;
    prot.WL_SURFACE.destroy = destroy;
}
