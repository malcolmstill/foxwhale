const std = @import("std");
const fs = std.fs;
const prot = @import("protocols.zig");
const epoll = @import("epoll");
const connections = @import("connection.zig");
const Connection = @import("connection.zig").Connection;
const Context = @import("connection.zig").Context;
const Object = @import("connection.zig").Object;

var conn: Connection = undefined;
var waiting: bool = true;

const Operation = enum {
    Clients,
    Windows,
    WindowTrees,
};

var operation: ?Operation = null;

pub fn main() anyerror!void {
    try epoll.init();

    var args_it = std.process.args();
    while (args_it.nextPosix()) |arg| {
        if (args_it.inner.index == 2) {
            if (std.mem.eql(u8, arg, "clients")) {
                operation = .Clients;
            }

            if (std.mem.eql(u8, arg, "windows")) {
                operation = .Windows;
            }

            if (std.mem.eql(u8, arg, "window-tree")) {
                operation = .WindowTrees;
            }
        }
    }

    if (operation == null) {
        return error.NoValidOperationProvided;
    }

    prot.WL_DISPLAY.delete_id = delete_id;
    prot.WL_REGISTRY.global = global;
    prot.WL_CALLBACK.done = callback_done;
    prot.FW_CONTROL.client = client;
    prot.FW_CONTROL.window = window;
    prot.FW_CONTROL.toplevel_window = toplevel_window;
    prot.FW_CONTROL.region_rect = region_rect;
    prot.FW_CONTROL.done = done;

    var file = try std.net.connectUnixSocket("/run/user/1000/wayland-0");
    conn.dispatchable.impl = connections.dispatch;
    conn.context.init(file.handle, &conn);

    try epoll.addFd(file.handle, &conn.dispatchable);

    var wl_display = prot.new_wl_display(1, &conn.context, 0);
    try conn.context.register(wl_display);
    var wl_registry = prot.new_wl_registry(2, &conn.context, 0);
    try conn.context.register(wl_registry);
    var wl_callback = prot.new_wl_callback(3, &conn.context, 0);
    try conn.context.register(wl_callback);

    try prot.wl_display_send_get_registry(wl_display, 2);
    try prot.wl_display_send_sync(wl_display, 3);

    while (waiting) {
        var i: usize = 0;
        var n = epoll.wait(-1);

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }
    }
}

fn delete_id(context: *Context, wl_display: Object, id: u32) anyerror!void {
    if (context.objects.get(id)) |wl_object| {
        try context.unregister(wl_object);
    }
}

fn global(context: *Context, wl_registry: Object, name: u32, interface: []u8, version: u32) anyerror!void {
    if (std.mem.eql(u8, interface, "fw_control\x00\x00")) {
        try prot.wl_registry_send_bind(wl_registry, name, "fw_control\x00", 1, 4);
        var fw_control = prot.new_fw_control(4, context, 0);
        try conn.context.register(fw_control);

        // As soon as we've bound the interface we can send our query
        switch (operation.?) {
            .Clients => try prot.fw_control_send_get_clients(fw_control),
            .Windows => try prot.fw_control_send_get_windows(fw_control),
            .WindowTrees => try prot.fw_control_send_get_window_trees(fw_control),
        }
    }
}

fn callback_done(context: *Context, wl_callback: Object, callback_data: u32) anyerror!void {
    // std.debug.warn("done!\n", .{});
}

fn client(context: *Context, fw_control: Object, client_index: u32) anyerror!void {
    std.debug.warn("client[{}]\n", .{client_index});
}

fn window(context: *Context, fw_control: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) anyerror!void {
    switch (operation.?) {
        .Windows => windowsWindow(index, parent, wl_surface_id, surface_type, x, y, width, height, sibling_prev, sibling_next, children_prev, children_next, input_region_id),
        .WindowTrees => windowTressWindow(index, parent, wl_surface_id, surface_type, x, y, width, height, sibling_prev, sibling_next, children_prev, children_next, input_region_id),
        else => return error.WindowNotExpectedForOp,
    }
}

fn windowsWindow(index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) void {
    var st = @intToEnum(prot.fw_control_surface_type, surface_type);

    std.debug.warn("window[{} ^", .{index});
    if (parent < 0) {
        std.debug.warn(" null]", .{});
    } else {
        std.debug.warn(" {}]", .{parent});
    }
    std.debug.warn(" @{}", .{wl_surface_id});
    switch (st) {
        prot.fw_control_surface_type.wl_surface => std.debug.warn(" (wl_surface)", .{}),
        prot.fw_control_surface_type.wl_subsurface => std.debug.warn(" (wl_subsurface)", .{}),
        prot.fw_control_surface_type.xdg_toplevel => std.debug.warn(" (xdg_toplevel)", .{}),
        prot.fw_control_surface_type.xdg_popup => std.debug.warn(" (xdg_popup)", .{}),
    }

    std.debug.warn(" ({}, {}) ({}, {}) [{}, {}] [{}, {}]\n", .{ x, y, width, height, sibling_prev, sibling_next, children_prev, children_next });

    if (input_region_id > 0) {
        std.debug.warn("\tinput_region_id: {}\n", .{input_region_id});
    }
}

fn windowTressWindow(index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, sibling_prev: i32, sibling_next: i32, children_prev: i32, children_next: i32, input_region_id: u32) void {
    var st = @intToEnum(prot.fw_control_surface_type, surface_type);
    std.debug.warn("    window[{} ^", .{index});
    if (parent < 0) {
        std.debug.warn(" null]", .{});
    } else {
        std.debug.warn(" {}]", .{parent});
    }
    std.debug.warn(" @{}", .{wl_surface_id});
    switch (st) {
        prot.fw_control_surface_type.wl_surface => std.debug.warn(" (wl_surface)", .{}),
        prot.fw_control_surface_type.wl_subsurface => std.debug.warn(" (wl_subsurface)", .{}),
        prot.fw_control_surface_type.xdg_toplevel => std.debug.warn(" (xdg_toplevel)", .{}),
        prot.fw_control_surface_type.xdg_popup => std.debug.warn(" (xdg_popup)", .{}),
    }

    std.debug.warn(" ({}, {}) ({}, {}) [{}, {}] [{}, {}]\n", .{ x, y, width, height, sibling_prev, sibling_next, children_prev, children_next });
}

fn toplevel_window(context: *Context, fw_control: Object, index: u32, parent: i32, wl_surface_id: u32, surface_type: u32, x: i32, y: i32, width: i32, height: i32, input_region_id: u32) anyerror!void {
    var st = @intToEnum(prot.fw_control_surface_type, surface_type);

    std.debug.warn("window[{} ^", .{index});
    if (parent < 0) {
        std.debug.warn(" null]", .{});
    } else {
        std.debug.warn(" {}]", .{parent});
    }
    std.debug.warn(" @{}", .{wl_surface_id});
    switch (st) {
        prot.fw_control_surface_type.wl_surface => std.debug.warn(" (wl_surface)", .{}),
        prot.fw_control_surface_type.wl_subsurface => std.debug.warn(" (wl_subsurface)", .{}),
        prot.fw_control_surface_type.xdg_toplevel => std.debug.warn(" (xdg_toplevel)", .{}),
        prot.fw_control_surface_type.xdg_popup => std.debug.warn(" (xdg_popup)", .{}),
    }

    std.debug.warn(" ({}", .{x});
    std.debug.warn(", {})", .{y});
    std.debug.warn(" ({}", .{width});
    std.debug.warn(", {}):\n", .{height});
}

fn region_rect(context: *Context, fw_control: Object, index: u32, x: i32, y: i32, width: i32, height: i32, op: i32) anyerror!void {
    std.debug.warn("\t\trect[{}]:\n", .{index});
    std.debug.warn("\t\t\tx: {}\n", .{x});
    std.debug.warn("\t\t\ty: {}\n", .{y});
    std.debug.warn("\t\t\twidth: {}\n", .{width});
    std.debug.warn("\t\t\theight: {}\n", .{height});
    std.debug.warn("\t\t\top: {s}\n", .{if (op == 1) "Add" else "Sub"});
}

fn done(context: *Context, fw_control: Object) anyerror!void {
    waiting = false;
}
