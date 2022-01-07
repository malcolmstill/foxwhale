const std = @import("std");
const views = @import("view.zig");
const xkbcommon = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;
const ClientCursor = @import("cursor.zig").ClientCursor;
const backend = @import("backend/backend.zig");

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

    running: bool,

    const Self = @This();

    pub fn init(self: *Self) !void {
        self.xkb = try xkbcommon.init();

        backend.BACKEND_FNS.keyboard = keyboardHandler;
        backend.BACKEND_FNS.mouseClick = mouseClickHandler;
        backend.BACKEND_FNS.mouseMove = mouseMoveHandler;
        backend.BACKEND_FNS.mouseAxis = mouseAxisHandler;
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32) !void {
        if (button == 224 or button == 25) { // 25 = p
            self.running = false;
        }

        if (self.xkb) |*xkb| {
            xkb.updateKey(button, action);
            self.mods_depressed = xkb.serializeDepressed();
            self.mods_latched = xkb.serializeLatched();
            self.mods_locked = xkb.serializeLocked();
            self.mods_group = xkb.serializeGroup();
        }
        try views.CURRENT_VIEW.keyboard(time, button, action);
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

    pub fn mouseMove(self: *Self, dx: f64, dy: f64) !void {
        self.pointer_x = self.pointer_x + dx;
        self.pointer_y = self.pointer_y + dy;

        if (self.pointer_x < 0) {
            self.pointer_x = 0;
        }

        if (self.pointer_x > @intToFloat(f64, views.CURRENT_VIEW.output.?.getWidth())) {
            self.pointer_x = @intToFloat(f64, views.CURRENT_VIEW.output.?.getWidth());
        }

        if (self.pointer_y < 0) {
            self.pointer_y = 0;
        }

        if (self.pointer_y > @intToFloat(f64, views.CURRENT_VIEW.output.?.getHeight())) {
            self.pointer_y = @intToFloat(f64, views.CURRENT_VIEW.output.?.getHeight());
        }

        if (self.move) |move| {
            var new_window_x = move.window_x + @floatToInt(i32, self.pointer_x - move.pointer_x);
            var new_window_y = move.window_y + @floatToInt(i32, self.pointer_y - move.pointer_y);
            move.window.current().x = new_window_x;
            move.window.pending().x = new_window_x;
            move.window.current().y = new_window_y;
            move.window.pending().y = new_window_y;
            return;
        }

        if (self.resize) |resize| {
            try resize.resize(self.pointer_x, self.pointer_y);
            return;
        }

        try views.CURRENT_VIEW.updatePointer(self.pointer_x, self.pointer_y);
    }

    pub fn mouseAxis(self: *Self, time: u32, axis: u32, value: f64) !void {
        try views.CURRENT_VIEW.mouseAxis(time, axis, -1.0 * value);
    }
};

fn keyboardHandler(time: u32, button: u32, state: u32) !void {
    try COMPOSITOR.keyboard(time, button, state);
}

fn mouseClickHandler(time: u32, button: u32, state: u32) !void {
    try COMPOSITOR.mouseClick(button, state);
}

fn mouseMoveHandler(time: u32, x: f64, y: f64) !void {
    try COMPOSITOR.mouseMove(x, y);
}

fn mouseAxisHandler(time: u32, axis: u32, value: f64) !void {
    try COMPOSITOR.mouseAxis(time, axis, value);
}

fn makeCompositor() Compositor {
    return Compositor{
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
        .running = true,
    };
}
