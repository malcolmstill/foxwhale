const std = @import("std");
const linux = std.os.linux;
const prot = @import("../protocols.zig");
const Renderer = @import("../renderer.zig").Renderer;
const compositor = @import("../compositor.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Client = @import("../client.zig").Client;
const ShmBuffer = @import("../shm_buffer.zig").ShmBuffer;
const Buffer = @import("../buffer.zig").Buffer;
const Window = @import("../window.zig").Window;
const Region = @import("../region.zig").Region;
const Link = @import("../window.zig").Link;

fn commit(context: *Context, wl_surface: Object) anyerror!void {
    const window = @intToPtr(*Window, wl_surface.container);
    defer {
        if (!window.synchronized) window.flip();
    }

    const wl_buffer_id = window.wl_buffer_id orelse return;
    const wl_buffer = context.get(wl_buffer_id) orelse return;

    const buffer = @intToPtr(*Buffer, wl_buffer.container);
    buffer.beginAccess();

    if (window.texture) |texture| {
        window.texture = null;
        try Renderer.releaseTexture(texture);
    }

    // We need to set pending here (rather than in ack_configure) because
    // we need to know the width and height of the new buffer
    if (compositor.COMPOSITOR.resize) |resize| {
        if (resize.window == window) {
            window.pending().x += resize.offsetX(window.width, buffer.width());
            window.pending().y += resize.offsetY(window.height, buffer.height());
        }
    }

    window.width = buffer.width();
    window.height = buffer.height();
    window.texture = try buffer.makeTexture();

    if (window.first_buffer == false) {
        window.first_buffer = true;
    }

    try buffer.endAccess();
    try prot.wl_buffer_send_release(wl_buffer);
    window.wl_buffer_id = null;

    if (window.view) |view| {
        if (window.xdg_toplevel_id != null) {
            if (window.toplevel.prev == null and window.toplevel.next == null) {
                view.remove(window);
                view.push(window);
            }
        }
    }

    if (window.xdg_surface_id != null) {
        if (window.first_configure and window.first_buffer and window.mapped == false) {
            try window.firstCommit();
            window.mapped = true;
        }
    }
}

fn set_buffer_scale(_: *Context, wl_surface: Object, scale: i32) anyerror!void {
    var pending = @intToPtr(*Window, wl_surface.container).pending();
    pending.scale = scale;
}

fn damage(
    _: *Context,
    _: Object, // wl_surface
    _: i32, // x
    _: i32, // y
    _: i32, // height
    _: i32, // height
) anyerror!void {
    // std.debug.warn("damage does nothing\n", .{});
}

fn attach(
    _: *Context,
    wl_surface: Object,
    optional_wl_buffer: ?Object,
    _: i32, // x
    _: i32, // y
) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    // window.pending = true;
    if (optional_wl_buffer) |wl_buffer| {
        window.wl_buffer_id = wl_buffer.id;
    } else {
        window.wl_buffer_id = null;
    }
}

fn offset(
    _: *Context,
    wl_surface: Object,
    x: i32, // x
    y: i32, // y
) anyerror!void {
    _ = @intToPtr(*Window, wl_surface.container);
    std.log.info("Offset x = {} y = {}", .{ x, y });
}

fn frame(context: *Context, wl_surface: Object, new_id: u32) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    try window.callbacks.writeItem(new_id);

    var callback = prot.new_wl_callback(new_id, context, 0);
    try context.register(callback);
}

// TODO: Should we store a *Region instead of a wl_region id?
fn set_opaque_region(
    _: *Context,
    wl_surface: Object,
    optional_wl_region: ?Object,
) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    if (optional_wl_region) |wl_region| {
        var region = @intToPtr(*Region, wl_region.container);
        region.window = window;

        // If we set a second pending input region before the first pending input region has been
        // flipped, we need to deinit the origin pending region
        if (window.pending().opaque_region) |old_pending_region| {
            if (old_pending_region != region and old_pending_region != window.current().opaque_region) {
                try old_pending_region.deinit();
            }
        }

        window.pending().opaque_region = region;
    } else {
        if (window.pending().opaque_region) |old_pending_region| {
            if (old_pending_region != window.current().opaque_region) {
                try old_pending_region.deinit();
            }
        }
        window.pending().opaque_region = null;
    }
}

// TODO: Should we store a *Region instead of a wl_region id?
fn set_input_region(_: *Context, wl_surface: Object, optional_wl_region: ?Object) anyerror!void {
    var window = @intToPtr(*Window, wl_surface.container);
    if (optional_wl_region) |wl_region| {
        var region = @intToPtr(*Region, wl_region.container);
        region.window = window;

        // If we set a second pending input region before the first pending input region has been
        // flipped, we need to deinit the original pending region
        if (window.pending().input_region) |old_pending_region| {
            if (old_pending_region != region and old_pending_region != window.current().input_region) {
                try old_pending_region.deinit();
            }
        }

        window.pending().input_region = region;
    } else {
        if (window.pending().input_region) |old_pending_region| {
            if (old_pending_region != window.current().input_region) {
                try old_pending_region.deinit();
            }
        }

        window.pending().input_region = null;
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
    prot.WL_SURFACE = prot.wl_surface_interface{
        .destroy = destroy,
        .attach = attach,
        .offset = offset,
        .damage = damage,
        .frame = frame,
        .set_opaque_region = set_opaque_region,
        .set_input_region = set_input_region,
        .commit = commit,
        .set_buffer_transform = set_buffer_transform,
        .set_buffer_scale = set_buffer_scale,
        .damage_buffer = damage_buffer,
    };
}

fn set_buffer_transform(
    _: *Context,
    _: Object,
    _: i32, // transform
) anyerror!void {}

fn damage_buffer(
    _: *Context,
    _: Object,
    _: i32, // x
    _: i32, // y
    _: i32, // width
    _: i32, // height
) anyerror!void {}
