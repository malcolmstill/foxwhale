const std = @import("std");
const prot = @import("../protocols.zig");
const positioners = @import("../positioner.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;

fn get_xdg_surface(context: *Context, xdg_wm_base: Object, new_id: u32, surface: Object) anyerror!void {
    std.debug.warn("get_xdg_surface: {}\n", .{new_id});

    const window = @intToPtr(*Window, surface.container);
    window.xdg_surface_id = new_id;

    const xdg_surface = prot.new_xdg_surface(new_id, context, @ptrToInt(window));
    try context.register(xdg_surface);
}

fn destroy(context: *Context, xdg_wm_base: Object) anyerror!void {
    // TODO: Should we deinit client?
    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_wm_base.id);
    try context.unregister(xdg_wm_base);
}

pub fn init() void {
    prot.XDG_WM_BASE = prot.xdg_wm_base_interface{
        .destroy = destroy,
        .create_positioner = create_positioner,
        .get_xdg_surface = get_xdg_surface,
        .pong = pong,
    };
}

fn create_positioner(context: *Context, xdg_wm_base: Object, new_id: u32) anyerror!void {
    const positioner = try positioners.newPositioner(context.client, new_id);
    const xdg_positioner = prot.new_xdg_positioner(new_id, context, @ptrToInt(positioner));
    try context.register(xdg_positioner);
}

fn pong(context: *Context, object: Object, serial: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}