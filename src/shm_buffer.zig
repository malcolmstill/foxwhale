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
        if (SHM_BUFFERS[i].in_use == false) {
            SHM_BUFFERS[i].index = i;
            SHM_BUFFERS[i].client = client;
            SHM_BUFFERS[i].in_use = true;
            SHM_BUFFERS[i].pool = @intToPtr(*ShmPool, wl_shm_pool.container);
            SHM_BUFFERS[i].offset = offset;
            SHM_BUFFERS[i].width = width;
            SHM_BUFFERS[i].height = height;
            SHM_BUFFERS[i].stride = stride;
            SHM_BUFFERS[i].format = format;
            SHM_BUFFERS[i].wl_buffer_id = id;

            SHM_BUFFERS[i].pool.incrementRefCount();

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

    const Self = @This();

    pub fn deinit(self: *Self) void {
        std.debug.warn("deinit buffer\n", .{});
        self.in_use = false;
    }
};

pub fn releaseShmBuffers(client: *Client) void {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        if (SHM_BUFFERS[i].client == client) {
            SHM_BUFFERS[i].deinit();
        }
        i = i + 1;
    }
}

const ShmBuffersError = error{ShmBuffersExhausted};
