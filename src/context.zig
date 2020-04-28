const object = @import("object.zig");

pub const Context = struct {
    saved_offset: usize = 0,
    buffer: [16]u8,
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, .Dynamic);

    pub fn init(fd: i32) Context {
        return Context {
            .fds = FifoType.init(std.heap.page_allocator),
        };
    }

    pub fn dispatch(self: *Self, fd: i32) !void {
        std.debug.warn("\nnumber: 0 1 2 3 4 5 6 7 8 9 A B C D E F\n", .{});
        var offset: usize = 0;
        var n = try std.os.read(fd, self.buffer[self.saved_offset..self.buffer.len]);
        n = self.saved_offset + n; // how much data we have

        std.debug.warn("buffer: {x}, saved_offset: {}, offset: {}, n: {}\n", .{self.buffer, self.saved_offset, offset, n});
        defer {
            std.mem.copy(u8, self.buffer[0..(n-offset)], self.buffer[offset..n]);
            self.saved_offset = n-offset;
            std.debug.warn("duffer: {x}, saved_offset: {}, offset: {}, n: {}\n", .{self.buffer, self.saved_offset, offset, n});
        }

        while (offset < n) {
            var remaining = n - offset;
            // We need to have read at least a header
            if (remaining < @sizeOf(object.MessageHeader)) {
                return;
            }

            var h = @ptrCast(*object.MessageHeader, &self.buffer[offset]);
            std.debug.warn("id: {}\nlength: {}\nopcode: {}\n", .{ h.id, h.length, h.opcode });

            // We need to have read a full message
            if (remaining < h.length) {
                return;
            }

            std.debug.warn("paylod: {x}\n", .{ self.buffer[offset..offset+h.length] });
            offset = offset + h.length;
        }
    }
};

const std = @import("std");
const fifo = std.fifo;
