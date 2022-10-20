const std = @import("std");
const os = std.os;
const mem = std.mem;
const linux = os.linux;

pub fn Epoll(comptime Subsystem: type, comptime SubsystemIterator: type, comptime Event: type, comptime Target: type) type {
    const EventTagType = switch (@typeInfo(Event)) {
        .Union => |info| info.tag_type orelse @compileError("Expected tag type"),
        else => @compileError("Event type must be union"),
    };
    const TargetTagType = switch (@typeInfo(Target)) {
        .Union => |info| info.tag_type orelse @compileError("Expected tag type"),
        else => @compileError("Event type must be union"),
    };
    if (EventTagType != Subsystem) @compileError("Subsystem must match Event tag");
    if (TargetTagType != Subsystem) @compileError("Subsystem must match Target tag");

    return struct {
        alloc: mem.Allocator,
        fd: i32,
        events: [256]linux.epoll_event = undefined,
        targets: std.AutoHashMap(i32, Target),

        const Self = @This();

        pub fn init(alloc: mem.Allocator) !Self {
            const epfd = try os.epoll_create1(linux.EPOLL.CLOEXEC);
            const targets = std.AutoHashMap(i32, Target).init(alloc);

            return Self{
                .alloc = alloc,
                .fd = epfd,
                .targets = targets,
            };
        }

        pub fn deinit(self: *Self) void {
            os.close(self.fd);
            self.targets.deinit();
        }

        pub fn wait(self: *Self, timeout: i32) Iterator {
            const n = os.epoll_wait(self.fd, self.events[0..], timeout);

            return Iterator{
                .epoll = self,
                .n = n,
            };
        }

        const Iterator = struct {
            i: usize = 0,
            n: usize,
            it: ?SubsystemIterator = null,
            epoll: *Epoll(Subsystem, SubsystemIterator, Event, Target),

            pub fn next(self: *Iterator) !?Event {
                if (self.i == self.n) return null;

                if (self.it == null) {
                    const fd = self.epoll.events[self.i].data.fd;
                    const target = self.epoll.targets.get(fd) orelse return error.ExpectedTarget;

                    self.it = target.iterator();
                }

                const event = try self.it.?.next(self.epoll.events[self.i].events);
                if (event == null) {
                    self.i += 1;
                    self.it = null;
                }

                return event;
            }
        };

        pub fn addFd(self: *Self, fd: i32, target: Target) !void {
            try self.targets.put(fd, target);

            var ev = linux.epoll_event{
                .events = linux.EPOLL.IN,
                .data = linux.epoll_data{
                    .fd = fd,
                },
            };

            try os.epoll_ctl(self.fd, linux.EPOLL.CTL_ADD, fd, &ev);
        }

        pub fn removeFd(self: *Self, fd: i32) !void {
            var ev = linux.epoll_event{
                .events = linux.EPOLL.IN,
                .data = linux.epoll_data{
                    .ptr = undefined,
                },
            };

            try os.epoll_ctl(self.fd, linux.EPOLL.CTL_DEL, fd, &ev);
        }
    };
}
