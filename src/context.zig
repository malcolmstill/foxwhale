pub const Context = struct {
    write_offset: usize = 0,
    recv_fds: [rm.MAX_FDS]i32,
    recv_buf: [512]u8,
    fds: FifoType,

    const Self = @This();
    const FifoType = std.fifo.LinearFifo(isize, .Dynamic);

    pub fn init(fd: i32) Context {
        return Context {
            .fds = FifoType.init(std.heap.page_allocator),
        };
    }

    pub fn dispatch(self: *Self, fd: i32) !void {
        var n = try rm.recvMsg(fd, self.recv_buf[self.write_offset..self.recv_buf.len], self.recv_fds[0..self.recv_fds.len]);
        n = self.write_offset + n;

        var offset: usize = 0;
        defer {
            self.write_offset = n - offset;
            std.mem.copy(u8, self.recv_buf[0..self.write_offset], self.recv_buf[offset..n]);
        }

        while (offset < n) {
            var remaining = n - offset;

            // We need to have read at least a header
            if (remaining < @sizeOf(protocol.Header)) {
                return;
            }

            var header = @ptrCast(*protocol.Header, &self.recv_buf[offset]);
            std.debug.warn("{}\n", .{ header });

            // We need to have read a full message
            if (remaining < header.length) {
                return;
            }

            std.debug.warn("paylod: {x}\n", .{ self.recv_buf[offset..offset+header.length] });
            offset = offset + header.length;
        }
    }
};

const std = @import("std");
const protocol = @import("protocol.zig");
const fifo = std.fifo;
const rm = @import("recvmsg.zig");