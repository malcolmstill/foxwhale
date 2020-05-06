const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const shm_pool = @import("shm_pool.zig");
const ShmPool = @import("shm_pool.zig").ShmPool;

fn create_pool(context: *Context, wl_shm: Object, new_id: u32, fd: i32, size: i32) anyerror!void {
    var pool = try shm_pool.newShmPool(context.client, fd, new_id, size);

    var wl_pool = wl.new_wl_shm_pool(new_id, context, @ptrToInt(pool));
    try context.register(wl_pool);
}

fn destroy(context: *Context, wl_shm_pool: Object) anyerror!void {
    var pool = @intToPtr(*ShmPool, wl_shm_pool.container);
    pool.to_be_destroyed = true;
}

pub fn init() void {
    wl.WL_SHM.create_pool = create_pool;
    wl.WL_SHM_POOL.destroy = destroy;
}