const std = @import("std");
const prot = @import("../protocols.zig");
const shm_buffer = @import("../shm_buffer.zig");
const Object = @import("../client.zig").Object;
const Context = @import("../client.zig").Context;
const Buffer = @import("../buffer.zig").Buffer;

fn destroy(context: *Context, wl_buffer: Object) anyerror!void {
    var buffer = @intToPtr(*Buffer, wl_buffer.container);
    switch (buffer.*) {
        Buffer.Shm => |*shmbuf| shmbuf.shm_pool.decrementRefCount(),
        else => {},
    }
    try buffer.deinit();

    // We still want to do this
    try prot.wl_display_send_delete_id(context.client.wl_display, wl_buffer.id);
    try context.unregister(wl_buffer);
}

pub fn init() void {
    prot.WL_BUFFER.destroy = destroy;
}