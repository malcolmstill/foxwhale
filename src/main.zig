const std = @import("std");
const Context = @import("wl/context.zig").Context;
const Display = @import("display.zig").Display;
const epoll = @import("epoll.zig");
const init = @import("init.zig");

pub fn main() anyerror!void {
    try epoll.init();

    var display = try Display.init();
    defer { display.deinit(); }
    try display.addToEpoll();

    init.init();

    while (true) {
        var n = epoll.wait(-1);
        std.debug.warn("\n\nactivity on epoll\n", .{});
        var i: usize = 0;

        while (i < n) {
            epoll.dispatch(i);
            i = i + 1;
        }
    }
}
