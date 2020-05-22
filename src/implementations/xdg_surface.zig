const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Rectangle = @import("../rectangle.zig").Rectangle;
const Window = @import("../window.zig").Window;
const XdgConfigurations = @import("../window.zig").XdgConfigurations;

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

fn set_window_geometry(context: *Context, xdg_surface: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    var window = @intToPtr(*Window, xdg_surface.container);

    window.window_geometry = Rectangle {
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

fn ack_configure(context: *Context, xdg_surface: Object, serial: u32) anyerror!void {
    var window = @intToPtr(*Window, xdg_surface.container);

    while(window.xdg_configurations.readItem()) |xdg_configuration| {
        if (serial == xdg_configuration.serial) {
            switch (xdg_configuration.operation) {
                .Maximize => {
                    if (window.maximized == null) {
                        window.pending().x = 0;
                        window.pending().y = 0;

                        window.maximized = Rectangle {
                            .x = window.current().x,
                            .y = window.current().y,
                            .width = if (window.window_geometry) |wg| wg.width else window.width,
                            .height = if (window.window_geometry) |wg| wg.height else window.height,
                        };
                    }
                },
                .Unmaximize => {
                    if (window.maximized) |maximized| {
                        window.pending().x = maximized.x;
                        window.pending().y = maximized.y;
                        window.maximized = null;
                    }
                },
            }
        }
    } else |err| {

    }

    window.xdg_configurations = XdgConfigurations.init();
}

fn destroy(context: *Context, xdg_surface: Object) anyerror!void {
    var window = @intToPtr(*Window, xdg_surface.container);
    window.xdg_surface_id = null;

    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_surface.id);
    try context.unregister(xdg_surface);
}

pub fn init() void {
    prot.XDG_SURFACE.get_toplevel = get_toplevel;
    prot.XDG_SURFACE.set_window_geometry = set_window_geometry;
    prot.XDG_SURFACE.ack_configure = ack_configure;
    prot.XDG_SURFACE.destroy = destroy;
}