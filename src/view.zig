const std = @import("std");
const prot = @import("wl/protocols.zig");
const Focus = @import("focus.zig").Focus;
const Window = @import("resource/window.zig").Window;

pub const View = struct {
    top: ?*Window = null,
    pointer_window: ?*Window = null,
    active_window: ?*Window = null,
    focus: Focus = .Click,

    const Self = @This();

    pub fn init() View {
        return View{};
    }

    pub fn visible(_: *const Self) bool {
        return true;
    }

    pub fn back(view: *const Self) ?*Window {
        var it = view.top;
        var window: ?*Window = null;
        while (it) |w| : (it = w.toplevel.prev) {
            window = w;
        }

        return window;
    }

    pub fn push(view: *Self, window: *Window) void {
        if (view.top) |top| {
            if (top == window) return;

            top.toplevel.next = window;
            window.toplevel.prev = top;
        }

        view.top = window;
    }

    pub fn remove(view: *Self, window: *Window) void {
        if (view.top == window) {
            view.top = window.toplevel.prev;
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
        while (it) |window| : (it = window.toplevel.prev) {
            window.toplevel.mark = false;
        }

        // 2. Raise our parent if it exists
        if (raising_window.parent) |parent| {
            // var root = pointer_window.root();
            const parent_toplevel = parent.toplevelWindow();
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
        while (it) |window| : (it = window.toplevel.next) {
            if (window.toplevel.mark == true) break;
            if (window.parent != raising_window.toplevelWindow()) continue;

            self.remove(window);
            self.push(window);
            window.toplevel.mark = true;
        }
    }

    pub fn updatePointer(self: *Self, x: f64, y: f64) !void {
        var new_pointer_window: ?*Window = null;

        var it = self.top;
        while (it) |window| : (it = window.toplevel.prev) {
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
                try window.pointerEnter(x, y);
                if (self.focus == Focus.FollowsMouse) {
                    try window.activate();
                    self.active_window = window;
                }
            } else {
                std.log.warn("new pointer_window: null\n", .{});
                // FIXME: reinstate
                // compositor.COMPOSITOR.client_cursor = null;
            }
        }

        self.pointer_window = new_pointer_window;

        if (self.pointer_window) |window| {
            try window.pointerMotion(x, y);
        }
    }

    pub fn keyboard(self: *Self, time: u32, button: u32, action: u32) !void {
        const active_window = self.active_window orelse return;
        try active_window.keyboardKey(time, button, action);
    }

    pub fn mouseAxis(self: *Self, time: u32, axis: u32, value: f64) !void {
        const pointer_window = self.pointer_window orelse return;
        try pointer_window.mouseAxis(time, axis, value);
    }
};
