const std = @import("std");
const Window = @import("window.zig").Window;

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    top: ?*Window,
    pointer_window: ?*Window,

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

    pub fn mouseClick(self: *Self, button: i32, action: i32) void {
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
            // window.mouseClick(button, action);
        }
    }

    pub fn updatePointer(self: *Self, x: f64, y: f64) void {
        var it = self.top;
        while(it) |window| : (it = window.toplevel.prev) {
            if (window.windowUnderPointer(x, y)) |w| {
                if (w != self.pointer_window) {
                    std.debug.warn("new pointer_surface: {}\n", .{w.index});
                }
                self.pointer_window = w;
                return;
            }
        }
        if (self.pointer_window != null) {
            std.debug.warn("new pointer_surface: null\n", .{});
        }
        self.pointer_window = null;
    }

    pub fn deinit(self: *Self) void {

    }
};

pub fn makeView() View {
    return View{
        .top = null,
        .pointer_window = null,
    };
}