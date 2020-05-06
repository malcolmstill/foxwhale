const std = @import("std");
const wl = @import("wl/protocols.zig");
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;

const MAX_SHM_POOLS = 512;
var pools: [MAX_SHM_POOLS]ShmPool = undefined;

pub fn init() void {
    wl.WL_SHM.create_pool = create_pool;
    wl.WL_SHM_POOL.destroy = destroy;
}

fn create_pool(shm: Object, id: u32, fd: i32, size: i32) anyerror!void {
    var context = shm.context;
    if (wl.new_wl_shm_pool(shm.context, id)) |wl_pool| {
        var pool = try newShmPool(context.client, fd, id);
        wl_pool.container = @ptrToInt(pool);
    }
}

fn destroy(shm_pool: Object) anyerror!void {
    var pool = @intToPtr(*ShmPool, shm_pool.container);
    pool.to_be_destroyed = true;
}

pub const ShmPool = struct {
    index: usize,
    in_use: bool = false,
    fd: i32,
    data: []u8,
    pool: ?u32,
    ref_count: usize,
    client: *Client,
    to_be_destroyed: bool = false,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.in_use = false;
        self.pool = null;
        self.fd = -1;
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

pub fn newShmPool(client: *Client, fd: i32, pool: u32) !*ShmPool {
    var i: usize = 0;
    while (i < MAX_SHM_POOLS) {
        if (pools[i].in_use == false) {
            pools[i].index = i;
            pools[i].in_use = true;
            pools[i].client = client;
            pools[i].fd = fd;
            pools[i].ref_count = 0;
            pools[i].pool = pool;

            return &pools[i];
        } else {
            i = i + 1;
            continue;
        }
    }

    return ShmPoolsError.ShmPoolsExhausted;
}

const ShmPoolsError = error {
    ShmPoolsExhausted,
};