const std = @import("std");
const ctx = @import("context.zig");
const wl = @import("display.zig");
const epoll = @import("epoll.zig");

pub fn main() anyerror!void {
    std.debug.warn("Booting zig-wayland\n", .{});

    try epoll.init();

    var display = try wl.Display.init();
    defer { display.deinit(); }

    // Let's do this
    while (true) {
        var n = epoll.wait(-1);
        var i: usize = 0;

        while (i < n) {
            epoll.dispatch(i);
            i = i + 1;
        }
    }
}