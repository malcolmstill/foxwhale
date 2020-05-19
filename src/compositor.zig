const std = @import("std");
const views = @import("view.zig");
const xkb = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;
pub var COMPOSITOR: Compositor = makeCompositor();

const Compositor = struct {
    pointer_x: i32,
    pointer_y: i32,

    cursor_wl_surface_id: ?u32,

    xkb: ?Xkb,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    mods_group: u32,

    const Self = @This();

    pub fn init(self: *Self) !void {
        self.xkb = try xkb.init();
    }

    pub fn updatePointer(self: *Self, new_x: f64, new_y: f64) !void {
        self.pointer_x = @floatToInt(i32, new_x);
        self.pointer_y = @floatToInt(i32, new_y);

        try views.CURRENT_VIEW.updatePointer(new_x, new_y);
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        // std.debug.warn("button: {}, action: {}\n", .{button, action});
        try views.CURRENT_VIEW.mouseClick(button, action);
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32, mods: u32) !void {
        if (self.xkb) |*x| {
            x.updateKey(button, action);
            self.mods_depressed = x.serializeDepressed();
            self.mods_latched = x.serializeLatched();
            self.mods_locked = x.serializeLocked();
            self.mods_group = x.serializeGroup();
        }
        try views.CURRENT_VIEW.keyboard(time, button, action, mods);
    }
};

fn makeCompositor() Compositor {
    return Compositor {
        .pointer_x = 0.0,
        .pointer_y = 0.0,
        .cursor_wl_surface_id = null,
        .xkb = null,
        .mods_depressed = 0,
        .mods_latched = 0,
        .mods_locked = 0,
        .mods_group = 0,
    };
}