const std = @import("std");
const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;
const Window = @import("window.zig").Window;

fn set_parent(context: *Context, xdg_toplevel: Object, parent: ?Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    window.parent = if (parent) |p| @intToPtr(*Window, p.container) else null;
}

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}

fn set_max_size(context: *Context, xdg_toplevel: Object, width: i32, height: i32) anyerror!void {
    var pending = @intToPtr(*Window, xdg_toplevel.container).pending();

    if (width <= 0) {
        pending.max_width = null;
    } else {
        pending.max_width = width;
    }

    if (height <= 0) {
        pending.max_height = null;
    } else {
        pending.max_height = height;
    }
}

fn set_min_size(context: *Context, xdg_toplevel: Object, width: i32, height: i32) anyerror!void {
    var pending = @intToPtr(*Window, xdg_toplevel.container).pending();

    if (width <= 0) {
        pending.min_width = null;
    } else {
        pending.min_width = width;
    }

    if (height <= 0) {
        pending.min_height = null;
    } else {
        pending.min_height = height;
    }
}

fn destroy(context: *Context, xdg_toplevel: Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    window.xdg_toplevel_id = null;

    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_toplevel.id);
    try context.unregister(xdg_toplevel);
}

pub fn init() void {
    prot.XDG_TOPLEVEL.set_parent = set_parent;
    prot.XDG_TOPLEVEL.set_title = set_title;
    prot.XDG_TOPLEVEL.set_max_size = set_max_size;
    prot.XDG_TOPLEVEL.set_min_size = set_min_size;
    prot.XDG_TOPLEVEL.destroy = destroy;
}
