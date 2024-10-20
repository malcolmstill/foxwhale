const std = @import("std");
const os = std.os;
const mem = std.mem;
const linux = os.linux;

pub fn Epoll(comptime Subsystem: type, comptime SubsystemIterator: type, comptime Event: type, comptime Target: type) type {
    const EventTagType = switch (@typeInfo(Event)) {
        .@"union" => |info| info.tag_type orelse @compileError("Expected tag type"),
        else => @compileError("Event type must be union"),
    };
    const TargetTagType = switch (@typeInfo(Target)) {
        .@"union" => |info| info.tag_type orelse @compileError("Expected tag type"),
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
            const epfd = try std.posix.epoll_create1(linux.EPOLL.CLOEXEC);
            const targets = std.AutoHashMap(i32, Target).init(alloc);

            return .{
                .alloc = alloc,
                .fd = epfd,
                .targets = targets,
            };
        }

        pub fn deinit(epoll: *Self) void {
            std.posix.close(epoll.fd);
            epoll.targets.deinit();
        }

        pub fn wait(epoll: *Self, timeout: i32) Iterator {
            const n = std.posix.epoll_wait(epoll.fd, epoll.events[0..], timeout);

            return .{
                .epoll = epoll,
                .n = n,
            };
        }

        const Iterator = struct {
            i: usize = 0,
            n: usize,
            sub_it: ?SubsystemIterator = null,
            epoll: *Epoll(Subsystem, SubsystemIterator, Event, Target),

            pub fn next(it: *Iterator) !?Event {
                if (it.i == it.n) return null;

                if (it.sub_it == null) {
                    const fd = it.epoll.events[it.i].data.fd;
                    const target = it.epoll.targets.get(fd) orelse return error.ExpectedTarget;

                    it.sub_it = target.iterator();
                }

                const event = try it.sub_it.?.next(it.epoll.events[it.i].events);
                if (event == null) {
                    it.i += 1;
                    it.sub_it = null;
                }

                return event;
            }
        };

        pub fn addFd(epoll: *Self, fd: i32, target: Target) !void {
            try epoll.targets.put(fd, target);

            var ev = linux.epoll_event{
                .events = linux.EPOLL.IN,
                .data = linux.epoll_data{
                    .fd = fd,
                },
            };

            try std.posix.epoll_ctl(epoll.fd, linux.EPOLL.CTL_ADD, fd, &ev);
        }

        pub fn removeFd(epoll: *Self, fd: i32) !void {
            var ev = linux.epoll_event{
                .events = linux.EPOLL.IN,
                .data = linux.epoll_data{
                    .ptr = undefined,
                },
            };

            try std.posix.epoll_ctl(epoll.fd, linux.EPOLL.CTL_DEL, fd, &ev);
        }
    };
}
