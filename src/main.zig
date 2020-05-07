const std = @import("std");
const Context = @import("wl/context.zig").Context;
const Display = @import("display.zig").Display;
const epoll = @import("epoll.zig");

pub fn main() anyerror!void {
    try epoll.init();

    var display = try Display.init();
    defer { display.deinit(); }
    try display.addToEpoll();

    while (true) {
        var n = epoll.wait(-1);
        var i: usize = 0;

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }
    }
}
