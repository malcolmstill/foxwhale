const std = @import("std");
const views = @import("view.zig");
pub var COMPOSITOR: Compositor = makeCompositor();

const Compositor = struct {
    pointer_x: i32,
    pointer_y: i32,

    const Self = @This();

    pub fn updatePointer(self: *Self, new_x: f64, new_y: f64) void {
        self.pointer_x = @floatToInt(i32, new_x);
        self.pointer_y = @floatToInt(i32, new_y);

        views.CURRENT_VIEW.updatePointer(new_x, new_y);
    }

    pub fn mouseClick(self: *Self, button: i32, action: i32) void {
        // std.debug.warn("button: {}, action: {}\n", .{button, action});
        views.CURRENT_VIEW.mouseClick(button, action);
    }
};

fn makeCompositor() Compositor {
    return Compositor {
        .pointer_x = 0.0,
        .pointer_y = 0.0,
    };
}