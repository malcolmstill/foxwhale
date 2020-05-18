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

    pub fn mouseClick(self: *Self, button: i32, action: i32) void {
        if (self.pointer_window) |pointer_window| {
            if (self.top) |top| {
                if (top != pointer_window) {
                    pointer_window.detach();
                    pointer_window.placeAbove(top);
                }
            }
            // window.mouseClick(button, action);
        }
    }

    pub fn updatePointer(self: *Self, x: f64, y: f64) void {
        if (self.top) |top| {
            var it = top.subwindowIterator();
            while(it.next()) |window| {
                if (window.windowUnderPointer(x, y)) |w| {
                    if (w != self.pointer_window) {
                        std.debug.warn("new pointer_surface: {}\n", .{w.index});
                    }
                    self.pointer_window = w;
                }
            }
        }
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