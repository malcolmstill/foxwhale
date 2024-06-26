const std = @import("std");
const os = std.os;
const linux = os.linux;
const Client = @import("../client.zig").Client;
const wl = @import("../client.zig").wl;

pub const ShmPool = struct {
    client: *Client,
    fd: i32,
    data: []align(4096) u8 = undefined,
    wl_shm_pool: wl.WlShmPool,
    ref_count: usize = 0,
    to_be_destroyed: bool = false,

    const Self = @This();

    pub fn init(client: *Client, fd: i32, wl_shm_pool: wl.WlShmPool, size: i32) !ShmPool {
        const data = try std.posix.mmap(null, @intCast(size), linux.PROT.READ | linux.PROT.WRITE, linux.MAP{ .TYPE = .SHARED }, fd, 0);

        return ShmPool{
            .client = client,
            .fd = fd,
            .wl_shm_pool = wl_shm_pool,
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        std.posix.munmap(self.data);
        std.posix.close(self.fd);

        self.fd = -1;
    }

    pub fn resize(self: *Self, size: i32) !void {
        std.posix.munmap(self.data);

        self.data = try std.posix.mmap(null, @intCast(size), linux.PROT.READ | linux.PROT.WRITE, linux.MAP{ .TYPE = .SHARED }, self.fd, 0);
    }

    pub fn incrementRefCount(self: *Self) void {
        self.ref_count += 1;
    }

    pub fn decrementRefCount(self: *Self) void {
        if (self.ref_count > 0) {
            self.ref_count -= 1;
            if (self.ref_count == 0 and self.to_be_destroyed) {
                self.deinit();
            }
        }
    }
};

const ShmPoolsError = error{
    ShmPoolsExhausted,
};
