const std = @import("std");
const d = @import("dispatchable.zig");

var epfd: i32 = -1;
var events: [256]std.os.linux.epoll_event = undefined;

pub fn init() !void {
    epfd = try std.os.epoll_create1(0);
}

pub fn wait(timeout: i32) usize {
    return std.os.epoll_wait(epfd, events[0..events.len], timeout);
}
 
pub fn addFd(fd: i32, dis: *d.Dispatchable) !void {
    var ev = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLLIN,
        .data = std.os.linux.epoll_data {
            .ptr = @ptrToInt(dis),
        },
    };

    try std.os.epoll_ctl(epfd, std.os.EPOLL_CTL_ADD, fd, &ev);
}

pub fn removeFd(fd: i32) !void {
    var ev = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLLIN,
        .data = std.os.linux.epoll_data {
            .ptr = undefined,
        },
    };

    try std.os.epoll_ctl(epfd, std.os.EPOLL_CTL_DEL, fd, &ev);
}

pub fn dispatch(i: usize) void {
    var ev = @intToPtr(*d.Dispatchable, events[i].data.ptr);
    ev.dispatch(events[i].events);
}