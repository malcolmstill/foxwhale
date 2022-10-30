const std = @import("std");
const mem = std.mem;
const views = @import("view.zig");
const xkbcommon = @import("xkb.zig");
const Xkb = @import("xkb.zig").Xkb;
const Move = @import("move.zig").Move;
const Resize = @import("resize.zig").Resize;
const ClientCursor = @import("cursor.zig").ClientCursor;
const AnimationList = @import("animatable.zig").AnimationList;
const ArrayList = std.ArrayList;
const Client = @import("client.zig").Client;
const Output = @import("resource/output.zig").Output;
const Backend = @import("backend/backend.zig").Backend;
const bknd = @import("backend/backend.zig");
const Server = @import("server.zig").Server;
const View = @import("view.zig").View;

pub var COMPOSITOR: Compositor = undefined;

pub const Compositor = struct {
    pointer_x: f64 = 0.0,
    pointer_y: f64 = 0.0,

    client_cursor: ?ClientCursor = null,

    move: ?Move = null,
    resize: ?Resize = null,

    xkb: ?Xkb = null,
    mods_depressed: u32 = 0,
    mods_latched: u32 = 0,
    mods_locked: u32 = 0,
    mods_group: u32 = 0,

    alloc: mem.Allocator,
    server: Server,
    clients: ArrayList(*Client),
    outputs: ArrayList(*Output),
    animations: AnimationList,
    current_view: ?*View = null,

    running: bool = true,

    const Self = @This();

    pub fn init(alloc: mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .server = undefined,
            .clients = ArrayList(*Client).init(alloc),
            .outputs = ArrayList(*Output).init(alloc),
            .animations = AnimationList.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.server.deinit();
        self.animations.deinit();
    }

    pub fn initServer(self: *Self) !void {
        self.server = try Server.init();
        try self.server.addToEpoll();
    }

    pub fn initOutputs(self: *Self, backend: *Backend) !void {
        const output = try Output.init(self, backend, self.alloc, 640, 480);
        try output.backend.addToEpoll();

        try self.outputs.append(output);
        self.current_view = &output.views[0];
    }

    pub fn initInput(self: *Self) !void {
        self.xkb = try xkbcommon.init();

        bknd.BACKEND_FNS.keyboard = keyboardHandler;
        bknd.BACKEND_FNS.mouseClick = mouseClickHandler;
        bknd.BACKEND_FNS.mouseMove = mouseMoveHandler;
        bknd.BACKEND_FNS.mouseAxis = mouseAxisHandler;
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

        const view = self.current_view orelse return;
        try view.keyboard(time, button, action);
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        if (self.move) |_| {
            if (action == 0) {
                self.move = null;
            }
        }

        if (self.resize) |_| {
            if (action == 0) {
                self.resize = null;
            }
        }

        const view = self.current_view orelse return;
        try view.mouseClick(button, action);
    }

    pub fn mouseMove(self: *Self, dx: f64, dy: f64) !void {
        const view = self.current_view orelse return;
        const width = @intToFloat(f64, view.output.?.backend.getWidth());
        const height = @intToFloat(f64, view.output.?.backend.getHeight());

        self.pointer_x = self.pointer_x + dx;
        self.pointer_y = self.pointer_y + dy;

        if (self.pointer_x < 0) {
            self.pointer_x = 0;
        }

        if (self.pointer_x > width) {
            self.pointer_x = width;
        }

        if (self.pointer_y < 0) {
            self.pointer_y = 0;
        }

        if (self.pointer_y > height) {
            self.pointer_y = height;
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

        try view.updatePointer(self.pointer_x, self.pointer_y);
    }

    pub fn mouseAxis(self: *Self, time: u32, axis: u32, value: f64) !void {
        const view = self.current_view orelse return;
        try view.mouseAxis(time, axis, -1.0 * value);
    }
};

fn keyboardHandler(time: u32, button: u32, state: u32) !void {
    try COMPOSITOR.keyboard(time, button, state);
}

fn mouseClickHandler(_: u32, button: u32, state: u32) !void {
    try COMPOSITOR.mouseClick(button, state);
}

fn mouseMoveHandler(_: u32, x: f64, y: f64) !void {
    try COMPOSITOR.mouseMove(x, y);
}

fn mouseAxisHandler(time: u32, axis: u32, value: f64) !void {
    try COMPOSITOR.mouseAxis(time, axis, value);
}

// fn makeCompositor() Compositor {
//     return Compositor{
//         .pointer_x = 0.0,
//         .pointer_y = 0.0,
//         .client_cursor = null,
//         .move = null,
//         .resize = null,
//         .xkb = null,
//         .mods_depressed = 0,
//         .mods_latched = 0,
//         .mods_locked = 0,
//         .mods_group = 0,
//         .running = true,
//     };
// }
