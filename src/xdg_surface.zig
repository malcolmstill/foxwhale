const std = @import("std");
const prot = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const Window = @import("window.zig").Window;

fn get_toplevel(context: *Context, xdg_surface: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_toplevel: {}\n", .{new_id});

    var window = @intToPtr(*Window, xdg_surface.container);
    window.xdg_toplevel_id = new_id;

    var xdg_toplevel = prot.new_xdg_toplevel(new_id, context, @ptrToInt(window));

    var array = [_]u32{};
    var serial = window.client.nextSerial();
    try prot.xdg_toplevel_send_configure(xdg_toplevel, 0, 0, array[0..array.len]);
    try prot.xdg_surface_send_configure(xdg_surface, serial);

    try context.register(xdg_toplevel);
}

fn ack_configure(context: *Context, xdg_surface: Object, serial: u32) anyerror!void {
    std.debug.warn("ack_configure empty implementation\n", .{});
}

fn destroy(context: *Context, xdg_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_surface.container);
    window.xdg_surface_id = null;

    try prot.wl_display_send_delete_id(context.client.display, xdg_surface.id);
    try context.unregister(xdg_surface);
}

pub fn init() void {
    prot.XDG_SURFACE.get_toplevel = get_toplevel;
    prot.XDG_SURFACE.ack_configure = ack_configure;
    prot.XDG_SURFACE.destroy = destroy;
}