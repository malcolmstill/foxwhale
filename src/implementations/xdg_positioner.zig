const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Positioner = @import("../positioner.zig").Positioner;
const Rectangle = @import("../rectangle.zig").Rectangle;

fn destroy(context: *Context, xdg_positioner: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_positioner.id);
    try context.unregister(xdg_positioner);
}

fn set_size(_: *Context, xdg_positioner: Object, width: i32, height: i32) anyerror!void {
    const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    positioner.width = width;
    positioner.height = height;
}

fn set_anchor_rect(_: *Context, xdg_positioner: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    positioner.anchor_rect = Rectangle{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

fn set_anchor(_: *Context, xdg_positioner: Object, anchor: u32) anyerror!void {
    const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    positioner.anchor = @intToEnum(prot.xdg_positioner_anchor, anchor);
}

fn set_gravity(_: *Context, xdg_positioner: Object, gravity: u32) anyerror!void {
    const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    positioner.gravity = @intToEnum(prot.xdg_positioner_gravity, gravity);
}

fn set_constraint_adjustment(
    _: *Context,
    _: Object, // xdg_positioner
    _: u32, // constraint_adjustment
) anyerror!void {
    // const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    // std.log.warn("constraint_adjustment: {}\n", .{constraint_adjustment});
    // positioner.constraint_adjustment = @intToEnum(prot.xdg_positioner_constraint_adjustment, constraint_adjustment);
}

fn set_offset(_: *Context, xdg_positioner: Object, x: i32, y: i32) anyerror!void {
    const positioner = @intToPtr(*Positioner, xdg_positioner.container);
    positioner.x = x;
    positioner.y = y;
}

fn set_reactive(
    _: *Context,
    _: Object,
) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn set_parent_size(
    _: *Context,
    _: Object,
    _: i32, // parent_width
    _: i32, // parent_height
) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn set_parent_configure(
    _: *Context,
    _: Object,
    _: u32, // serial
) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub fn init() void {
    prot.XDG_POSITIONER = prot.xdg_positioner_interface{
        .destroy = destroy,
        .set_size = set_size,
        .set_anchor_rect = set_anchor_rect,
        .set_anchor = set_anchor,
        .set_gravity = set_gravity,
        .set_constraint_adjustment = set_constraint_adjustment,
        .set_offset = set_offset,
        .set_reactive = set_reactive,
        .set_parent_size = set_parent_size,
        .set_parent_configure = set_parent_configure,
    };
}
