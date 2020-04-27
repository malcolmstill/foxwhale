const std = @import("std");
const ctx = @import("context.zig");
const wl = @import("display.zig");
const epoll = @import("epoll.zig");

pub fn main() anyerror!void {
    std.debug.warn("Booting zig-wayland\n", .{});
    // Initialise epoll
    try epoll.init();

    // Initialise wayland
    var display = try wl.Display.init();
    display.initDispatch();

    var wl_sock: i32 = display.server.sockfd orelse return;
    try epoll.addFd(wl_sock, &display.dispatchable);

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