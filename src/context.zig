pub const Context = struct {
    fd: i32,
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, .Dynamic);

    pub fn init(fd: i32) Context {
        return Context {
            .fd = fd,
            .fds = FifoType.init(std.heap.page_allocator),
        };
    }

    pub fn dispatch(self: *Self) void {
        std.debug.warn("Hello there {}\n", .{self});
    }

    pub fn read_event() void {}
};

const std = @import("std");
const fifo = std.fifo;
