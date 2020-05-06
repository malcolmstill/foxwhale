const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Window = @import("window.zig").Window;

pub fn init() void {
    wl.XDG_SURFACE.get_toplevel = get_toplevel;
    wl.XDG_SURFACE.ack_configure = ack_configure;
}

fn get_toplevel(context: *Context, xdg_surface: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_toplevel: {}\n", .{new_id});

    var window = @intToPtr(*Window, xdg_surface.container);
    window.xdg_toplevel = new_id;

    var xdg_toplevel = wl.new_xdg_toplevel(new_id, context, @ptrToInt(window));

    var array = [_]u32{};
    var serial = window.client.nextSerial();
    try wl.xdg_toplevel_send_configure(xdg_toplevel, 0, 0, array[0..array.len]);
    try wl.xdg_surface_send_configure(xdg_surface, serial);

    try context.register(xdg_toplevel);
}

fn ack_configure(context: *Context, object: Object, serial: u32) anyerror!void {
    std.debug.warn("ack_configure empty implementation\n", .{});
}