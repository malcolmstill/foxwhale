const std = @import("std");
const linux = std.os.linux;

var epfd: i32 = -1;
var events: [256]std.os.linux.epoll_event = undefined;

pub fn init() !void {
    epfd = try std.os.epoll_create1(linux.EPOLL.CLOEXEC);
}

pub fn wait(timeout: i32) usize {
    return std.os.epoll_wait(epfd, events[0..events.len], timeout);
}

pub fn addFd(fd: i32, dis: *Dispatchable) !void {
    var ev = linux.epoll_event{
        .events = linux.EPOLL.IN,
        .data = linux.epoll_data{
            .ptr = @ptrToInt(dis),
        },
    };

    try std.os.epoll_ctl(epfd, linux.EPOLL.CTL_ADD, fd, &ev);
}

pub fn removeFd(fd: i32) !void {
    var ev = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLL.IN,
        .data = std.os.linux.epoll_data{
            .ptr = undefined,
        },
    };

    try std.os.epoll_ctl(epfd, linux.EPOLL.CTL_DEL, fd, &ev);
}

// For a given event index that has activity
// call the Dispatchable function
pub fn dispatch(i: usize) !void {
    var ev = @intToPtr(*Dispatchable, events[i].data.ptr);
    try ev.dispatch(events[i].events);
}

// The Dispatchable interface allows for dispatching
// on epoll activity. A struct containing a Dispatchable
// can define a function that gets set as impl. The impl
// will be passed a pointer to container. The container
// will typically be (a pointer to) the struct itself.
pub const Dispatchable = struct {
    impl: *const fn (*Self, usize) anyerror!void,

    const Self = @This();

    pub fn dispatch(self: *Self, event_type: usize) !void {
        // self.impl(self, event_type) catch |err| {
        //     std.log.warn("Error dispatching epoll: {}\n", .{ err });
        // };
        try self.impl(self, event_type);
    }
};
