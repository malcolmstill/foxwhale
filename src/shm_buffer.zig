const std = @import("std");
const Object = @import("wl/context.zig").Object;
const Context = @import("wl/context.zig").Context;
const Client = @import("client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;
const wl = @import("wl/protocols.zig");

const MAX_SHM_BUFFERS = 2048;
var SHM_BUFFERS: [MAX_SHM_BUFFERS]ShmBuffer = undefined;

pub fn newShmBuffer(client: *Client, id: u32, wl_shm_pool: Object, offset: i32, width: i32, height: i32, stride: i32, format: u32) !*ShmBuffer {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        var shm_buffer: *ShmBuffer = &SHM_BUFFERS[i];
        if (shm_buffer.in_use == false) {
            shm_buffer.index = i;
            shm_buffer.client = client;
            shm_buffer.in_use = true;
            shm_buffer.shm_pool = @intToPtr(*ShmPool, wl_shm_pool.container);
            shm_buffer.offset = offset;
            shm_buffer.width = width;
            shm_buffer.height = height;
            shm_buffer.stride = stride;
            shm_buffer.format = format;
            shm_buffer.wl_buffer_id = id;

            shm_buffer.shm_pool.incrementRefCount();

            return shm_buffer;
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
    wl_buffer_id: u32,
    shm_pool: *ShmPool,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: u32,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        std.debug.warn("deinit buffer\n", .{});
        self.in_use = false;
    }
};

pub fn releaseShmBuffers(client: *Client) void {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        var shm_buffer: *ShmBuffer = &SHM_BUFFERS[i];
        if (shm_buffer.client == client) {
            shm_buffer.deinit();
        }
        i = i + 1;
    }
}

const ShmBuffersError = error{ShmBuffersExhausted};
