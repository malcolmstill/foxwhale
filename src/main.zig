const std = @import("std");
const ctx = @import("context.zig");
const wl = @import("wayland.zig");

pub fn main() anyerror!void {
    var l = try wl.socket();

    var epfd = try std.os.epoll_create1(0);
    var events: [64]std.os.linux.epoll_event = undefined;
    var wl_sock: i32 = -1;

    if (l.sockfd) |sockfd| {
        wl_sock = sockfd;
        std.debug.warn("socket fd {} \n", .{ sockfd });
        var ev = std.os.linux.epoll_event{
            .events = std.os.linux.EPOLLIN,
            .data = std.os.linux.epoll_data {
                .fd = sockfd,
            },
        };
        try std.os.epoll_ctl(epfd, std.os.EPOLL_CTL_ADD, sockfd, &ev);
    } else {
        return;
    }

    var buffer: [8]u8 = undefined;

    while (true) {
        var n = std.os.epoll_wait(epfd, events[0..events.len], -1);

        var i: usize = 0;

        while (i < n) {
            if (events[i].data.fd == wl_sock) {
                var client = try l.accept();
                std.debug.warn("client connected {} \n", .{ client });
            }

            // std.debug.warn("buffer {}, len {}\n", .{ &buffer[0], buffer.len });
            // var nr = try std.os.read(events[i].data.fd, buffer[0..buffer.len]);
            // std.debug.warn("read {} bytes\n", .{ nr });

            i = i + 1;
        }
    }

    var c = ctx.Context().init();
    try c.fds.writeItem(12);
}
