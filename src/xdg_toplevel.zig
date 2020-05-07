const std = @import("std");
const prot = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Window = @import("window.zig").Window;

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}

fn destroy(context: *Context, xdg_toplevel: Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    window.xdg_toplevel_id = null;

    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_toplevel.id);
    try context.unregister(xdg_toplevel);
}

pub fn init() void {
    prot.XDG_TOPLEVEL.set_title = set_title;
    prot.XDG_TOPLEVEL.destroy = destroy;
}
