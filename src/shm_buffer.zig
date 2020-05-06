const std = @import("std");
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;
const wl = @import("wl/protocols.zig");
const MAX_SHM_BUFFERS = 2048;
var SHM_BUFFERS: [MAX_SHM_BUFFERS]ShmBuffer = undefined;

pub fn init() void {
    wl.WL_SHM_POOL.create_buffer = create_buffer;
}

fn create_buffer(shm_pool: Object, id: u32, offset: i32, width: i32, height: i32, stride: i32, format: u32) anyerror!void {
    std.debug.warn("create_buffer empty implementation\n", .{});
    if (wl.new_wl_buffer(shm_pool.context, id)) |wl_buffer| {
        var pool = @intToPtr(*ShmPool, shm_pool.container);
        var buffer = try newShmBuffer(shm_pool.context.client, pool, offset, width, height, stride, format);
        buffer.buffer = id;
        wl_buffer.container = @ptrToInt(buffer);
        pool.ref_count += 1;
        
    }
}

pub fn newShmBuffer(client: *Client, pool: *ShmPool, offset: i32, width: i32, height: i32, stride: i32, format: u32) !*ShmBuffer {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        if (SHM_BUFFERS[i].in_use == false) {
            SHM_BUFFERS[i].index = i;
            SHM_BUFFERS[i].in_use = true;
            SHM_BUFFERS[i].offset = offset;
            SHM_BUFFERS[i].width = width;
            SHM_BUFFERS[i].height = height;
            SHM_BUFFERS[i].stride = stride;
            SHM_BUFFERS[i].format = format;

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
    buffer: ?u32,
    pool: *ShmPool,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: u32,
};

const ShmBuffersError = error{ShmBuffersExhausted};
