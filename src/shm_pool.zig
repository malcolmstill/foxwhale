const std = @import("std");
const Client = @import("client.zig").Client;

const MAX_SHM_POOLS = 512;
var pools: [MAX_SHM_POOLS]ShmPool = undefined;

pub const ShmPool = struct {
    index: usize,
    in_use: bool = false,
    fd: i32,
    data: []align(4096) u8,
    wl_shm_pool: ?u32,
    ref_count: usize,
    client: *Client,
    to_be_destroyed: bool = false,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.in_use = false;
        self.wl_shm_pool = null;
        self.fd = -1;
        std.os.munmap(self.data);
        std.debug.warn("released pool data\n", .{});
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

pub fn newShmPool(client: *Client, fd: i32, wl_shm_pool: u32, size: i32) !*ShmPool {
    var i: usize = 0;
    while (i < MAX_SHM_POOLS) {
        if (pools[i].in_use == false) {
            pools[i].index = i;
            pools[i].in_use = true;
            pools[i].client = client;
            pools[i].fd = fd;
            pools[i].ref_count = 0;
            pools[i].wl_shm_pool = wl_shm_pool;
            pools[i].data = try std.os.mmap(null, @intCast(usize, size), std.os.linux.PROT_READ|std.os.linux.PROT_WRITE, std.os.linux.MAP_SHARED, fd, 0);

            std.debug.warn("data length: {}\n", .{pools[i].data.len});

            return &pools[i];
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
        if (pools[i].client == client) {
            pools[i].deinit();
        }
        i = i + 1;
    }
}

const ShmPoolsError = error {
    ShmPoolsExhausted,
};