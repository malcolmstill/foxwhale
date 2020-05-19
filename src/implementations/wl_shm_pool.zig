const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const shm_pool = @import("../shm_pool.zig");
const ShmPool = @import("../shm_pool.zig").ShmPool;

fn create_pool(context: *Context, wl_shm: Object, new_id: u32, fd: i32, size: i32) anyerror!void {
    // std.debug.warn("create_pool: fd {}\n", .{fd});
    var pool = try shm_pool.newShmPool(context.client, fd, new_id, size);

    var wl_pool = prot.new_wl_shm_pool(new_id, context, @ptrToInt(pool));
    try context.register(wl_pool);
}

fn resize(context: *Context, wl_shm_pool: Object, size: i32) anyerror!void {
    var pool = @intToPtr(*ShmPool, wl_shm_pool.container);
    try pool.resize(size);
}

fn destroy(context: *Context, wl_shm_pool: Object) anyerror!void {
    var pool = @intToPtr(*ShmPool, wl_shm_pool.container);
    pool.to_be_destroyed = true;
}

pub fn init() void {
    prot.WL_SHM.create_pool = create_pool;
    prot.WL_SHM_POOL.resize = resize;
    prot.WL_SHM_POOL.destroy = destroy;
}