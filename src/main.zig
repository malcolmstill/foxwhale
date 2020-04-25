const std = @import("std");
const ctx = @import("context.zig");
const wl = @import("wayland.zig");
const d = @import("dispatchable.zig");

pub fn main() anyerror!void {
    // Initialise epoll
    var epfd = try std.os.epoll_create1(0);
    var events: [256]std.os.linux.epoll_event = undefined;

    // Initialise wayland
    var display = try wl.Display.init();
    display.dispatchable.container = @ptrToInt(&display);
    std.debug.warn("Display: {} at {x}\n", .{ display, @ptrToInt(&display) });
    var wl_sock: i32 = display.server.sockfd orelse return;
    try addFd(epfd, wl_sock, &display.dispatchable);

    // Let's do this
    while (true) {
        var n = std.os.epoll_wait(epfd, events[0..events.len], -1);
        // std.debug.warn("Got activity: {}\n", .{ n });
        var i: usize = 0;

        while (i < n) {
            var ev = @intToPtr(*d.Dispatchable, events[i].data.ptr);
            // std.debug.warn("ev: {}\n", .{ ev });
            ev.dispatch();
            i = i + 1;
        }
    }

    var c = ctx.Context.init(18);
    try c.fds.writeItem(12);
}

fn addFd(epfd: i32, fd: i32, dis: *d.Dispatchable) !void {
    var ev = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLLIN,
        .data = std.os.linux.epoll_data {
            .ptr = @ptrToInt(dis),
        },
    };

    try std.os.epoll_ctl(epfd, std.os.EPOLL_CTL_ADD, fd, &ev);
}