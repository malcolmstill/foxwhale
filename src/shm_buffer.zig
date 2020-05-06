const std = @import("std");
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;
const wl = @import("wl/protocols.zig");
const MAX_SHM_BUFFERS = 2048;
var SHM_BUFFERS: [MAX_SHM_BUFFERS]ShmBuffer = undefined;

pub fn init() void {
    wl.WL_SHM_POOL.create_buffer = create_buffer;
    wl.WL_BUFFER.destroy = destroy;
}

fn create_buffer(shm_pool: Object, id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    var pool = @intToPtr(*ShmPool, shm_pool.container);
    var context = shm_pool.context;

    if (wl.new_wl_buffer(context, id)) |wl_buffer| {
        var buffer = try newShmBuffer(context.client, id, pool, offset, width, height, stride, format);
        wl_buffer.container = @ptrToInt(buffer);
        pool.incrementRefCount();
    }
}

pub fn newShmBuffer(client: *Client, id: u32, pool: *ShmPool, offset: i32, width: i32, height: i32, stride: i32, format: u32) !*ShmBuffer {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        if (SHM_BUFFERS[i].in_use == false) {
            SHM_BUFFERS[i].index = i;
            SHM_BUFFERS[i].in_use = true;
            SHM_BUFFERS[i].pool = pool;
            SHM_BUFFERS[i].offset = offset;
            SHM_BUFFERS[i].width = width;
            SHM_BUFFERS[i].height = height;
            SHM_BUFFERS[i].stride = stride;
            SHM_BUFFERS[i].format = format;
            SHM_BUFFERS[i].wl_buffer_id = id;

            return &SHM_BUFFERS[i];
        } else {
            i = i + 1;
            continue;
        }
    }

    return ShmBuffersError.ShmBuffersExhausted;
}

pub const ShmBuffer = struct {
    index: usize,
    in_use: bool = false,
    client: *Client,
    wl_buffer_id: ?u32,
    pool: *ShmPool,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: u32,
};

fn destroy(shm_buffer: Object) anyerror!void {
    var context = shm_buffer.context;
    var buffer = @intToPtr(*ShmBuffer, shm_buffer.container);
    buffer.pool.decrementRefCount();
    if (context.get(1)) |display| {
        try wl.wl_display_send_delete_id(display.*, shm_buffer.id);
    }

    try shm_buffer.context.unregister(shm_buffer);
}

const ShmBuffersError = error{ShmBuffersExhausted};
