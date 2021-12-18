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

        fn deinit(self: *Self) void {
            os.close(self.fd);
        }

        pub fn next(self: *Self) !?Event {
            if (self.pair) |*pair| {
                if (pair.i == pair.n) {
                    self.pair = null;
                    return null;
                } else {
                    defer pair.i += 1;
                    return try self.dispatch(pair.i);
                }
            } else {
                const n = os.epoll_wait(self.fd, self.events[0..], self.timeout);

                if (n == 0) return null;

                self.pair = Pair{
                    .i = 1,
                    .n = n,
                };

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
        fn dispatch(self: *Self, i: usize) !Event {
            var ev = @intToPtr(*Dispatchable, self.events[i].data.ptr);
            return try ev.dispatch(self.events[i].events);
        }

        // The Dispatchable interface allows for dispatching
        // on epoll activity. A struct containing a Dispatchable
        // can define a function that gets set as impl. The impl
        // will be passed a pointer to container. The container
        // will typically be (a pointer to) the struct itself.
        pub const Dispatchable = struct {
            impl: fn (*DispatchableSelf, usize) anyerror!Event,

            const DispatchableSelf = @This();

            pub fn dispatch(self: *DispatchableSelf, event_type: usize) !Event {
                return try self.impl(self, event_type);
            }
        };
    };
}

const Pair = struct {
    i: usize,
    n: usize,
};

test "epoll is generic" {
    const SubsystemTypes = enum {
        Input,
        Client,
    };

    const ClientEvent = union {
        commit: usize,
    };

    const InputEvent = union {
        mouse_button: usize,
        keypress: usize,
    };

    const Event = union(SubsystemTypes) {
        Input: InputEvent,
        Client: ClientEvent,
    };

    var e = try Epoll(Event).init(0);
    defer e.deinit();

    while (try e.next()) |ev| {
        //
    }
}
