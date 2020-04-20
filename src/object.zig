const std = @import("std");
const fifo = std.fifo;

const wl_object = struct {
    id: u32,
};

pub const context = struct {
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, std.fifo.LinearFifoBufferType{ .Static = 32 });
    
    pub fn init(self: *Self) void {
        self.fds = FifoType.init();
    }

    pub fn dispatch() void {

    }

    pub fn read_event() void {

    }

    // pub fn push_fd(self: *Self, fd: isize) {
    //     self.fds.writeItem(12);
    // }

    // pub fn read
};

pub fn Context() context {
    return context {
        .fds = undefined,
    };
}