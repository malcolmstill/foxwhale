const std = @import("std");
const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;
const Window = @import("window.zig").Window;

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}

fn set_max_size(context: *Context, xdg_toplevel: Object, width: i32, height: i32) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);

    if (width <= 0) {
        window.max_width = null;
    } else {
        window.max_width = width;
    }

    if (height <= 0) {
        window.max_height = null;
    } else {
        window.max_height = height;
    }
}

fn set_min_size(context: *Context, xdg_toplevel: Object, width: i32, height: i32) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);

    if (width <= 0) {
        window.min_width = null;
    } else {
        window.min_width = width;
    }

    if (height <= 0) {
        window.min_height = null;
    } else {
        window.min_height = height;
    }
}

fn destroy(context: *Context, xdg_toplevel: Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    window.xdg_toplevel_id = null;

    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_toplevel.id);
    try context.unregister(xdg_toplevel);
}

pub fn init() void {
    prot.XDG_TOPLEVEL.set_title = set_title;
    prot.XDG_TOPLEVEL.set_max_size = set_max_size;
    prot.XDG_TOPLEVEL.set_min_size = set_min_size;
    prot.XDG_TOPLEVEL.destroy = destroy;
}
