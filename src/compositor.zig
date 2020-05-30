const std = @import("std");
const views = @import("view.zig");
const xkbcommon = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;
const ClientCursor = @import("cursor.zig").ClientCursor;
pub var COMPOSITOR: Compositor = makeCompositor();

const Compositor = struct {
    pointer_x: f64,
    pointer_y: f64,

    client_cursor: ?ClientCursor,

    move: ?Move,
    resize: ?Resize,

    xkb: ?Xkb,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    mods_group: u32,

    const Self = @This();

    pub fn init(self: *Self) !void {
        self.xkb = try xkbcommon.init();
    }

    pub fn updatePointer(self: *Self, new_x: f64, new_y: f64) !void {
        self.pointer_x = new_x;
        self.pointer_y = new_y;

        if (self.move) |move| {
            var new_window_x = move.window_x + @floatToInt(i32, new_x - move.pointer_x);
            var new_window_y = move.window_y + @floatToInt(i32, new_y - move.pointer_y);
            move.window.current().x = new_window_x;
            move.window.pending().x = new_window_x;
            move.window.current().y = new_window_y;
            move.window.pending().y = new_window_y;
            return;
        }

        if (self.resize) |resize| {
            try resize.resize(new_x, new_y);
            return;
        }

        try views.CURRENT_VIEW.updatePointer(new_x, new_y);
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        if (self.move) |move| {
            if (action == 0) {
                self.move = null;
            }
        }

        if (self.resize) |resize| {
            if (action == 0) {
                self.resize = null;
            }
        }

        try views.CURRENT_VIEW.mouseClick(button, action);
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32, mods: u32) !void {
        if (self.xkb) |*xkb| {
            xkb.updateKey(button, action);
            self.mods_depressed = xkb.serializeDepressed();
            self.mods_latched = xkb.serializeLatched();
            self.mods_locked = xkb.serializeLocked();
            self.mods_group = xkb.serializeGroup();
        }
        try views.CURRENT_VIEW.keyboard(time, button, action, mods);
    }
};

fn makeCompositor() Compositor {
    return Compositor {
        .pointer_x = 0.0,
        .pointer_y = 0.0,
        .client_cursor = null,
        .move = null,
        .resize = null,
        .xkb = null,
        .mods_depressed = 0,
        .mods_latched = 0,
        .mods_locked = 0,
        .mods_group = 0,
    };
}