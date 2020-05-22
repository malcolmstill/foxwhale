const std = @import("std");
const prot = @import("protocols.zig");
const Focus = @import("focus.zig").Focus;
const Output = @import("output.zig").Output;
const Window = @import("window.zig").Window;

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    output: ?*Output,
    top: ?*Window,
    pointer_window: ?*Window,
    active_window: ?*Window,
    focus: Focus,

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
    }

    pub fn remove(self: *Self, window: *Window) void {
        if (self.top == window) {
            self.top = window.toplevel.prev;
        }

        window.toplevel.deinit();
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        if (self.pointer_window) |pointer_window| {
            if (action == 1) {
                if (self.top != pointer_window) {
                        std.debug.warn("raise: {}\n", .{pointer_window.index});
                        var root = pointer_window.root();
                        self.remove(root);
                        self.push(root);
                }

                if (pointer_window != self.active_window) {
                    if (self.active_window) |active_window| {
                        try active_window.deactivate();
                    }

                    try pointer_window.activate();
                    self.active_window = pointer_window;
                }
            }

            try pointer_window.mouseClick(button, action);
        } else {
            if (self.active_window) |active_window| {
                if (action == 1) {
                    try active_window.deactivate();
                    self.active_window = null;
                }
            }
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
                if (self.focus == Focus.FollowsMouse) {
                    try old_pointer_window.deactivate();
                    self.active_window = null;
                }
            }

            if (new_pointer_window) |window| {
                std.debug.warn("new pointer_window: {}\n", .{window.index});
                try window.pointerEnter(x, y);
                if (self.focus == Focus.FollowsMouse) {
                    try window.activate();
                    self.active_window = window;
                }
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
        if (self.active_window) |active_window| {
            try active_window.keyboardKey(time, button, action);
        }
    }

    pub fn deinit(self: *Self) void {
        self.* = makeView(self.output);
    }
};

pub fn makeView(output: ?*Output) View {
    return View{
        .output = output,
        .top = null,
        .pointer_window = null,
        .active_window = null,
        .focus = Focus.Click,
    };
}