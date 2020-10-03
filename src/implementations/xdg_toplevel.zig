const std = @import("std");
const prot = @import("../protocols.zig");
const compositor = @import("../compositor.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;
const XdgConfiguration = @import("../window.zig").XdgConfiguration;
const Move = @import("../move.zig").Move;
const Resize = @import("../resize.zig").Resize;

fn set_parent(context: *Context, xdg_toplevel: Object, parent: ?Object) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);
    window.parent = if (parent) |p| @intToPtr(*Window, p.container) else null;
}

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);
    const len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    // std.debug.warn("window: {}\n", .{window.title});
}

fn set_app_id(context: *Context, xdg_toplevel: Object, app_id: []u8) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);
    const len = std.math.min(window.app_id.len, app_id.len);
    std.mem.copy(u8, window.app_id[0..len], app_id[0..len]);
}

fn set_max_size(context: *Context, xdg_toplevel: Object, width: i32, height: i32) anyerror!void {
    const pending = @intToPtr(*Window, xdg_toplevel.container).pending();

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
    const pending = @intToPtr(*Window, xdg_toplevel.container).pending();

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
    const window = @intToPtr(*Window, xdg_toplevel.container);
    window.xdg_toplevel_id = null;

    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_toplevel.id);
    try context.unregister(xdg_toplevel);
}

pub fn init() void {
    prot.XDG_TOPLEVEL = prot.xdg_toplevel_interface{
        .destroy = destroy,
        .set_parent = set_parent,
        .set_title = set_title,
        .set_app_id = set_app_id,
        .show_window_menu = show_window_menu,
        .move = move,
        .resize = resize,
        .set_max_size = set_max_size,
        .set_min_size = set_min_size,
        .set_maximized = set_maximized,
        .unset_maximized = unset_maximized,
        .set_fullscreen = set_fullscreen,
        .unset_fullscreen = unset_fullscreen,
        .set_minimized = set_minimized,
    };
}

fn show_window_menu(context: *Context, object: Object, seat: Object, serial: u32, x: i32, y: i32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

// TODO: Moving should be delegated to the current view's mode
fn move(context: *Context, xdg_toplevel: Object, seat: Object, serial: u32) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);

    if (window.maximized == null) {
        compositor.COMPOSITOR.move = Move {
            .window = window,
            .window_x = window.current().x,
            .window_y = window.current().y,
            .pointer_x = compositor.COMPOSITOR.pointer_x,
            .pointer_y = compositor.COMPOSITOR.pointer_y,
        };
    }
}

fn resize(context: *Context, xdg_toplevel: Object, seat: Object, serial: u32, edges: u32) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);

    compositor.COMPOSITOR.resize = Resize {
        .window = window,
        .window_x = window.current().x,
        .window_y = window.current().y,
        .pointer_x = compositor.COMPOSITOR.pointer_x,
        .pointer_y = compositor.COMPOSITOR.pointer_y,
        .width = (if (window.window_geometry) |wg| wg.width else window.width),
        .height = (if (window.window_geometry) |wg| wg.height else window.height),
        .direction = edges,
    };
}

fn set_maximized(context: *Context, xdg_toplevel: Object) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);

    if (window.view == null or window.view.?.output == null or window.xdg_surface_id == null) {
        return;
    }

    if (window.client.context.get(window.xdg_surface_id.?)) |xdg_surface| {
        const serial = window.client.nextSerial();
        try window.xdg_configurations.writeItem(XdgConfiguration {
            .serial = serial,
            .operation = .Maximize,
        });

        var states: [2]u32 = [_]u32{
            @enumToInt(prot.xdg_toplevel_state.maximized),
            @enumToInt(prot.xdg_toplevel_state.activated),
        };

        try prot.xdg_toplevel_send_configure(
            xdg_toplevel,
            window.view.?.output.?.getWidth(),
            window.view.?.output.?.getHeight(),
            &states);
        try prot.xdg_surface_send_configure(xdg_surface.*, serial);
    }
}

fn unset_maximized(context: *Context, xdg_toplevel: Object) anyerror!void {
    const window = @intToPtr(*Window, xdg_toplevel.container);

    if (window.view == null or window.view.?.output == null or window.xdg_surface_id == null) {
        return;
    }

    if (window.client.context.get(window.xdg_surface_id.?)) |xdg_surface| {
        const serial = window.client.nextSerial();
        try window.xdg_configurations.writeItem(XdgConfiguration {
            .serial = serial,
            .operation = .Unmaximize,
        });

        var states: [1]u32 = [_]u32{
            @enumToInt(prot.xdg_toplevel_state.activated),
        };

        if (window.maximized) |maximized| {
            try prot.xdg_toplevel_send_configure(
                xdg_toplevel,
                maximized.width,
                maximized.height,
                &states);
        } else {
            try prot.xdg_toplevel_send_configure(
                xdg_toplevel,
                window.width,
                window.height,
                &states);
        }
        try prot.xdg_surface_send_configure(xdg_surface.*, serial);
    }
}

fn set_fullscreen(context: *Context, object: Object, output: ?Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn unset_fullscreen(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn set_minimized(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}