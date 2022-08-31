const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const shm_pool = @import("../shm_pool.zig");
const shm_buffer = @import("../shm_buffer.zig");
const ShmPool = @import("../shm_pool.zig").ShmPool;

fn create_pool(
    context: *Context,
    _: Object, // wl_shm
    new_id: u32,
    fd: i32,
    size: i32,
) anyerror!void {
    // std.log.warn("create_pool: fd {}\n", .{fd});
    const pool = try shm_pool.newShmPool(context.client, fd, new_id, size);

    const wl_pool = prot.new_wl_shm_pool(new_id, context, @ptrToInt(pool));
    try context.register(wl_pool);
}

fn create_buffer(context: *Context, wl_shm_pool: Object, new_id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    const buffer = try shm_buffer.newShmBuffer(context.client, new_id, wl_shm_pool, offset, width, height, stride, format);

    const wl_buffer = prot.new_wl_buffer(new_id, context, @ptrToInt(buffer));
    try context.register(wl_buffer);
}

fn resize(_: *Context, wl_shm_pool: Object, size: i32) anyerror!void {
    const pool = @intToPtr(*ShmPool, wl_shm_pool.container);
    try pool.resize(size);
}

fn destroy(context: *Context, wl_shm_pool: Object) anyerror!void {
    const pool = @intToPtr(*ShmPool, wl_shm_pool.container);
    pool.to_be_destroyed = true;
    if (pool.ref_count == 0) {
        pool.deinit();
    }

    try prot.wl_display_send_delete_id(context.client.wl_display, wl_shm_pool.id);
    try context.unregister(wl_shm_pool);
}

pub fn init() void {
    prot.WL_SHM.create_pool = create_pool;
    prot.WL_SHM_POOL.create_buffer = create_buffer;
    prot.WL_SHM_POOL.resize = resize;
    prot.WL_SHM_POOL.destroy = destroy;
}
