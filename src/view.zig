const std = @import("std");
const prot = @import("protocols.zig");
const Focus = @import("focus.zig").Focus;
const CompositorOutput = @import("output.zig").CompositorOutput;
const Window = @import("window.zig").Window;
const compositor = @import("compositor.zig");

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    output: ?*CompositorOutput,
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
                if (self.top != pointer_window.toplevelWindow()) {
                    self.raise(pointer_window.toplevelWindow());
                }

                if (pointer_window.toplevelWindow() != self.active_window) {
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

    pub fn raise(self: *Self, raising_window: *Window) void {
        // 1. iterate down, removing any marks
        var it = self.top;
        while(it) |window| : (it = window.toplevel.prev) {
            window.toplevel.mark = false;
        }

        // 2. Raise our parent if it exists
        if (raising_window.parent) |parent| {
            // var root = pointer_window.root();
            var parent_toplevel = parent.toplevelWindow();
            parent.toplevel.mark = true;
            self.remove(parent_toplevel);
            self.push(parent_toplevel);
        }

        // 3. Raise our window
        var raising_window_toplevel = raising_window.toplevelWindow();
        self.remove(raising_window_toplevel);
        self.push(raising_window_toplevel);
        raising_window_toplevel.toplevel.mark = true;

        // 4. Raise any of our children
        it = self.back();
        while(it) |window| : (it = window.toplevel.next) {
            if (window.toplevel.mark == true) {
                break;
            }

            if (window.parent == raising_window.toplevelWindow()) {
                self.remove(window);
                self.push(window);
                window.toplevel.mark = true;
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
                compositor.COMPOSITOR.client_cursor = null;
            }
        }

        self.pointer_window = new_pointer_window;

        if (self.pointer_window) |window| {
            try window.pointerMotion(x, y);
        }
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32) !void {
        if (self.active_window) |active_window| {
            try active_window.keyboardKey(time, button, action);
        }
    }

    pub fn mouseAxis(self: *Self, time: u32, axis: u32, value: f64) !void {
        if (self.pointer_window) |pointer_window| {
            try pointer_window.mouseAxis(time, axis, value);
        }
    }

    pub fn deinit(self: *Self) void {
        self.* = makeView(self.output);
    }
};

pub fn makeView(output: ?*CompositorOutput) View {
    return View{
        .output = output,
        .top = null,
        .pointer_window = null,
        .active_window = null,
        .focus = Focus.Click,
    };
}