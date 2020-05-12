const std = @import("std");
const linux = std.os.linux;
const renderer = @import("renderer.zig");
const Object = @import("client.zig").Object;
const Context = @import("client.zig").Context;
const Client = @import("client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;

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
        self.in_use = false;
    }

    pub fn beginAccess(self: *Self) void {
        CURRENT_POOL_ADDRESS = self.shm_pool.data.ptr;
        CURRENT_POOL_SIZE = self.shm_pool.data.len;
        _ = linux.sigaction(linux.SIGBUS, &sigbus_handler_action, null);
    }

    pub fn endAccess(self: *Self) !void {
        defer {
            SIGBUS_ERROR = false;
            _ = linux.sigaction(linux.SIGBUS, &sigbus_handler_reset, null);
        }
        if (SIGBUS_ERROR) {
            return error.ClientSigbusd;
        }
    }

    pub fn makeTexture(self: *Self) !u32 {
        return renderer.makeTexture(self.width, self.height, self.stride, self.format, self.shm_pool.data);
    }
};

pub fn releaseShmBuffers(client: *Client) void {
    var i: usize = 0;
    while (i < MAX_SHM_BUFFERS) {
        var shm_buffer: *ShmBuffer = &SHM_BUFFERS[i];
        if (shm_buffer.in_use and shm_buffer.client == client) {
            shm_buffer.deinit();
        }
        i = i + 1;
    }
}

const ShmBuffersError = error{ShmBuffersExhausted};

var SIGBUS_ERROR = false;
var CURRENT_POOL_ADDRESS: [*]align(4096) u8 = undefined;
var CURRENT_POOL_SIZE: usize = 0;

const sigbus_handler_action = linux.Sigaction{
    .sigaction = sigbusHandler,
    .mask = linux.empty_sigset,
    .flags = linux.SA_RESETHAND,
};

const sigbus_handler_reset = linux.Sigaction{
    .sigaction = null,
    .mask = linux.empty_sigset,
    .flags = linux.SA_RESETHAND,
};

fn sigbusHandler(sig: i32, info: *linux.siginfo_t, data: ?*c_void) callconv(.C) void {
    SIGBUS_ERROR = true;
    _ = linux.mmap(CURRENT_POOL_ADDRESS, CURRENT_POOL_SIZE, linux.PROT_READ|linux.PROT_WRITE, linux.MAP_FIXED | linux.MAP_PRIVATE | linux.MAP_ANONYMOUS, -1, 0);
}
