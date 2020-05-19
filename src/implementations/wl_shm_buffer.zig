const std = @import("std");
const prot = @import("../protocols.zig");
const shm_buffer = @import("../shm_buffer.zig");
const Object = @import("../client.zig").Object;
const Context = @import("../client.zig").Context;
const ShmBuffer = @import("../shm_buffer.zig").ShmBuffer;

fn create_buffer(context: *Context, wl_shm_pool: Object, new_id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    var buffer = try shm_buffer.newShmBuffer(context.client, new_id, wl_shm_pool, offset, width, height, stride, format);

    var wl_buffer = prot.new_wl_buffer(new_id, context, @ptrToInt(buffer));
    try context.register(wl_buffer);
}

fn destroy(context: *Context, wl_shm_buffer: Object) anyerror!void {
    var buffer = @intToPtr(*ShmBuffer, wl_shm_buffer.container);
    buffer.shm_pool.decrementRefCount();
    buffer.deinit();

    try prot.wl_display_send_delete_id(context.client.wl_display, wl_shm_buffer.id);
    try context.unregister(wl_shm_buffer);
}

pub fn init() void {
    prot.WL_SHM_POOL.create_buffer = create_buffer;
    prot.WL_BUFFER.destroy = destroy;
}