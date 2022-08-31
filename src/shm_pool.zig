const std = @import("std");
const Client = @import("client.zig").Client;

const MAX_SHM_POOLS = 512;
var SHM_POOLS: [MAX_SHM_POOLS]ShmPool = undefined;

pub const ShmPool = struct {
    index: usize,
    in_use: bool = false,
    fd: i32,
    data: []align(4096) u8,
    wl_shm_pool_id: u32,
    ref_count: usize,
    client: *Client,
    to_be_destroyed: bool = false,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        std.os.munmap(self.data);
        // std.log.warn("shm_pool closing file descriptor: {}\n", .{self.fd});
        std.os.close(self.fd);

        self.in_use = false;
        self.fd = -1;
    }

    pub fn resize(self: *Self, size: i32) !void {
        std.os.munmap(self.data);
        self.data = try std.os.mmap(null, @intCast(usize, size), std.os.linux.PROT.READ | std.os.linux.PROT.WRITE, std.os.linux.MAP.SHARED, self.fd, 0);
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

pub fn newShmPool(client: *Client, fd: i32, wl_shm_pool_id: u32, size: i32) !*ShmPool {
    var i: usize = 0;
    while (i < MAX_SHM_POOLS) {
        var shm_pool: *ShmPool = &SHM_POOLS[i];
        if (shm_pool.in_use == false) {
            shm_pool.index = i;
            shm_pool.in_use = true;
            shm_pool.to_be_destroyed = false;
            shm_pool.client = client;
            shm_pool.fd = fd;
            shm_pool.ref_count = 0;
            shm_pool.wl_shm_pool_id = wl_shm_pool_id;
            shm_pool.data = try std.os.mmap(null, @intCast(usize, size), std.os.linux.PROT.READ | std.os.linux.PROT.WRITE, std.os.linux.MAP.SHARED, fd, 0);

            // std.log.warn("data length: {}\n", .{shm_pool.data.len});

            return shm_pool;
        } else {
            i = i + 1;
            continue;
        }
    }

    return ShmPoolsError.ShmPoolsExhausted;
}

pub fn releaseShmPools(client: *Client) void {
    var i: usize = 0;
    while (i < MAX_SHM_POOLS) {
        var shm_pool: *ShmPool = &SHM_POOLS[i];
        if (shm_pool.in_use and shm_pool.client == client) {
            shm_pool.deinit();
        }
        i = i + 1;
    }
}

const ShmPoolsError = error{
    ShmPoolsExhausted,
};
