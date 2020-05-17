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

    pub fn iterator(self: *Self) ?Window.SubwindowIterator {
        if(self.top) |top| {
            var it = top.subwindowIterator();

            // Go to back
            var maybe_window: ?*Window = null;
            while(it.prev()) |prev| {
                maybe_window = prev;
            }
            if (maybe_window) |window| {
                return window.subwindowIterator();
            }
        }
        return null;
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