const std = @import("std");
const os = std.os;
const linux = os.linux;

pub fn Epoll(comptime Event: type) type {
    return struct {
        fd: i32,
        events: [256]linux.epoll_event = undefined,
        timeout: i32,
        pair: ?Pair = null,

        const Self = @This();

        pub fn init(timeout: i32) !Self {
            const epfd = try os.epoll_create1(linux.EPOLL_CLOEXEC);

            return Self{
                .fd = epfd,
                .timeout = timeout,
            };
        }

        pub fn deinit(self: *Self) void {
            os.close(self.fd);
        }

        // TODO: Logic:
        // 1. We have already called epoll_wait and have some pending events
        //    to process. If i is now equal to n, we have read all our fds.
        //    Otherwise, dispatch on the current value of i. If that dispatch
        //    returns null, we have exhausted all events coming from the ith
        //    file descriptor. If we have more i's to go, move onto the next
        //    one and return the first dispatch of that fd.
        pub fn next(self: *Self) !?Event {
            if (self.pair) |*pair| {
                if (pair.i == pair.n) {
                    self.pair = null;
                    return null;
                } else {
                    // Dispatch the current file descriptor
                    const event_i = try self.dispatch(pair.i);

                    if (event_i) |ev_i| {
                        return ev_i; // We will check for another ev from this i next time
                    } else {
                        // Move onto next i, which should yield an event
                        pair.i += 1;
                        if (pair.i == pair.n) {
                            self.pair = null;
                            return null;
                        }

                        // Dispatch the next file descriptor
                        return try self.dispatch(pair.i);
                    }
                }
            } else {
                const n = os.epoll_wait(self.fd, self.events[0..], self.timeout);

                if (n == 0) return null;

                self.pair = Pair{
                    .i = 0,
                    .n = n,
                };

                // Dispatch the first file descriptor
                return try self.dispatch(0);
            }
        }

        pub fn addFd(self: *Self, fd: i32, dis: *Dispatchable) !void {
            var ev = linux.epoll_event{
                .events = linux.EPOLLIN,
                .data = linux.epoll_data{
                    .ptr = @ptrToInt(dis),
                },
            };

            // Not sure we want to resort to O_NONBLOCK to get our type-safe epoll event iterator
            _ = try os.fcntl(fd, os.F_SETFL, os.O_NONBLOCK);

            try os.epoll_ctl(self.fd, os.EPOLL_CTL_ADD, fd, &ev);
        }

        pub fn removeFd(self: *Self, fd: i32) !void {
            var ev = linux.epoll_event{
                .events = linux.EPOLLIN,
                .data = linux.epoll_data{
                    .ptr = undefined,
                },
            };

            try os.epoll_ctl(self.fd, os.EPOLL_CTL_DEL, fd, &ev);
        }

        // For a given event index that has activity
        // call the Dispatchable function
        fn dispatch(self: *Self, i: usize) !?Event {
            var ev = @intToPtr(*Dispatchable, self.events[i].data.ptr);
            return try ev.dispatch(self.events[i].events);
        }

        // The Dispatchable interface allows for dispatching
        // on epoll activity. A struct containing a Dispatchable
        // can define a function that gets set as impl. The impl
        // will be passed a pointer to container. The container
        // will typically be (a pointer to) the struct itself.
        pub const Dispatchable = struct {
            impl: fn (*DispatchableSelf, usize) anyerror!?Event,

            pub const DispatchableSelf = @This();

            pub fn dispatch(self: *DispatchableSelf, event_type: usize) !?Event {
                return try self.impl(self, event_type);
            }
        };
    };
}

const Pair = struct {
    i: usize,
    n: usize,
};

test "epoll pull test" {
    _ = @import("epoll_pull_test.zig");
}
