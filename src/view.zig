const std = @import("std");
const prot = @import("protocols.zig");
const Window = @import("window.zig").Window;

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    top: ?*Window,
    pointer_window: ?*Window,
    active_window: ?*Window,

    const Self = @This();

    pub fn visible(self: *Self) bool {
        return true;
    }

    pub fn back(self: *Self) ?*Window {
        var it = self.top;
        var window: ?*Window = null;
        while(it) |w| : (it = w.toplevel.prev) {
            window = w;
        }

        return window;
    }

    pub fn push(self: *Self, window: *Window) void {
        if (self.top) |top| {
            if (top == window) {
                return;
            }
            top.toplevel.next = window;
            window.toplevel.prev = top;
        }

        self.top = window;
        std.debug.warn("pushed\n", .{});
    }

    pub fn remove(self: *Self, window: *Window) void {
        if (self.top == window) {
            self.top = window.toplevel.prev;
        }
        window.toplevel.deinit();
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        if (self.pointer_window) |pointer_window| {
            if (self.top) |top| {
                if (top != pointer_window) {
                    if (action == 1) {
                        std.debug.warn("raise\n", .{});
                        self.remove(pointer_window);
                        self.push(pointer_window);
                    }
                }
            }
            try pointer_window.mouseClick(button, action);
        }
    }

    pub fn updatePointer(self: *Self, x: f64, y: f64) !void {
        var new_pointer_window: ?*Window = null;

        var it = self.top;
        while(it) |window| : (it = window.toplevel.prev) {
            if (window.windowUnderPointer(x, y)) |w| {
                new_pointer_window = w;
                break;
            }
        }

        if (new_pointer_window != self.pointer_window) {
            if (self.pointer_window) |old_pointer_window| {
                try old_pointer_window.pointerLeave();
                try old_pointer_window.deactivate();
            }

            if (new_pointer_window) |window| {
                std.debug.warn("new pointer_window: {}\n", .{window.index});
                try window.activate();
                try window.pointerEnter(x, y);
            } else {
                std.debug.warn("new pointer_window: null\n", .{});
            }
        }

        self.pointer_window = new_pointer_window;

        if (self.pointer_window) |window| {
            try window.pointerMotion(x, y);
        }
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32, mods: u32) !void {
        if (self.pointer_window) |window| {
            try window.keyboardKey(time, button, action);
        }
    }

    pub fn deinit(self: *Self) void {
        self.* = makeView();
    }
};

pub fn makeView() View {
    return View{
        .top = null,
        .pointer_window = null,
        .active_window = null,
    };
}