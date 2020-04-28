pub const Context = struct {
    write_offset: usize = 0,
    buffer: [512]u8,
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, .Dynamic);

    pub fn init(fd: i32) Context {
        return Context {
            .fds = FifoType.init(std.heap.page_allocator),
        };
    }

    pub fn dispatch(self: *Self, fd: i32) !void {
        var n = try std.os.read(fd, self.buffer[self.write_offset..self.buffer.len]);
        n = self.write_offset + n;

        var offset: usize = 0;
        defer {
            self.write_offset = n - offset;
            std.mem.copy(u8, self.buffer[0..self.write_offset], self.buffer[offset..n]);
        }

        while (offset < n) {
            var remaining = n - offset;

            // We need to have read at least a header
            if (remaining < @sizeOf(protocol.Header)) {
                return;
            }

            var header = @ptrCast(*protocol.Header, &self.buffer[offset]);
            std.debug.warn("{}\n", .{ header });

            // We need to have read a full message
            if (remaining < header.length) {
                return;
            }

            std.debug.warn("paylod: {x}\n", .{ self.buffer[offset..offset+header.length] });
            offset = offset + header.length;
        }
    }
};

const std = @import("std");
const protocol = @import("protocol.zig");
const fifo = std.fifo;
