const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Region = @import("../region.zig").Region;
const RegionOp = @import("../region.zig").RegionOp;
const RectangleOp = @import("../region.zig").RectangleOp;
const Rectangle = @import("../rectangle.zig").Rectangle;

fn add(_: *Context, wl_region: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    const region = @intToPtr(*Region, wl_region.container);

    var rect = RectangleOp{
        .rectangle = Rectangle{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        },
        .op = RegionOp.Add,
    };

    try region.rectangles.writeItem(rect);
}

fn subtract(_: *Context, wl_region: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    const region = @intToPtr(*Region, wl_region.container);

    var rect = RectangleOp{
        .rectangle = Rectangle{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        },
        .op = RegionOp.Subtract,
    };

    try region.rectangles.writeItem(rect);
}

fn destroy(context: *Context, wl_region: Object) anyerror!void {
    const region = @intToPtr(*Region, wl_region.container);
    if (region.window == null) {
        try region.deinit();
    }
    try prot.wl_display_send_delete_id(context.client.wl_display, wl_region.id);
    try context.unregister(wl_region);
}

pub fn init() void {
    prot.WL_REGION.add = add;
    prot.WL_REGION.subtract = subtract;
    prot.WL_REGION.destroy = destroy;
}
