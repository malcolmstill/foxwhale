const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Window = @import("window.zig").Window;

pub fn init() void {
    wl.XDG_TOPLEVEL.set_title = set_title;
}

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}