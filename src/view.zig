const std = @import("std");
const Window = @import("window.zig").Window;

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    top: ?*Window,

    const Self = @This();

    pub fn visible(self: *Self) bool {
        return true;
    }

    pub fn iterator(self: *Self) ?Window.ToplevelIterator {
        if(self.top) |top| {
            var it = top.toplevelIterator();

            // Go to back
            var maybe_window: ?*Window = null;
            while(it.prev()) |prev| {
                maybe_window = prev;
            }
            if (maybe_window) |window| {
                return window.toplevelIterator();
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
    };
}