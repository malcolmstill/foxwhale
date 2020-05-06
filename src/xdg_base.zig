const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Window = @import("window.zig").Window;

pub fn init() void {
    wl.XDG_WM_BASE.get_xdg_surface = get_xdg_surface;
}

fn get_xdg_surface(context: *Context, base: Object, new_id: u32, surface: Object) anyerror!void {
    std.debug.warn("get_xdg_surface: {}\n", .{new_id});

    var window = @intToPtr(*Window, surface.container);
    window.xdg_surface = new_id;

    var xdg_surface = wl.new_xdg_surface(new_id, context, @ptrToInt(window));
    try context.register(xdg_surface);
}