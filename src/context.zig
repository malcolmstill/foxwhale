
pub const context = struct {
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, .Dynamic);
    
    pub fn init(self: *Self) *Self {
        self.fds = FifoType.init(std.heap.page_allocator);
        return self;
    }

    pub fn dispatch(self: *Self) void {
        std.debug.warn("Hello there {}\n", .{ self });
    }

    pub fn read_event() void {

    }
};

pub fn Context() context {
    return context {
        .fds = undefined,
    };
}

const std = @import("std");
const fifo = std.fifo;