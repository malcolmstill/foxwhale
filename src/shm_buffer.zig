const std = @import("std");
const linux = std.os.linux;
const os = std.os;
const renderer = @import("renderer.zig");
const Object = @import("client.zig").Object;
const Context = @import("client.zig").Context;
const Client = @import("client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;

pub fn newShmBuffer(client: *Client, id: u32, wl_shm_pool: Object, offset: i32, width: i32, height: i32, stride: i32, format: u32) !*Buffer {
    const shm_buffer = ShmBuffer{
        .client = client,
        .shm_pool = @intToPtr(*ShmPool, wl_shm_pool.container),
        .offset = offset,
        .width = width,
        .height = height,
        .stride = stride,
        .format = format,
        .wl_buffer_id = id,
    };

    var buf = try buffer.newBuffer(client);
    buf.* = Buffer{ .Shm = shm_buffer };

    @intToPtr(*ShmPool, wl_shm_pool.container).incrementRefCount();
    return buf;
}

pub const ShmBuffer = struct {
    client: *Client,
    wl_buffer_id: u32,
    shm_pool: *ShmPool,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: u32,

    const Self = @This();

    pub fn deinit(self: *Self) void {}

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
        var offset = @intCast(usize, self.offset);
        return renderer.makeTexture(self.width, self.height, self.stride, self.format, self.shm_pool.data[offset..]);
    }
};

var SIGBUS_ERROR = false;
var CURRENT_POOL_ADDRESS: [*]align(4096) u8 = undefined;
var CURRENT_POOL_SIZE: usize = 0;

const sigbus_handler_action = os.Sigaction{
    .handler = .{ .sigaction = sigbusHandler },
    .mask = linux.empty_sigset,
    .flags = linux.SA_RESETHAND,
};

const sigbus_handler_reset = os.Sigaction{
    .handler = .{ .sigaction = null },
    .mask = linux.empty_sigset,
    .flags = linux.SA_RESETHAND,
};

// libwayland uses a cool trick of mmap'ing some new data underneath (i.e. at the
// same address as) the SHM buffer, essentially throwing away the SHM'ness of the
// memory and guaranteeing that when the code is retried that SIGBUS will not be
// raised.
// See: https://github.com/wayland-project/wayland/blob/11623e8fddb924c7ae317f2eabac23785ae5e8d5/src/wayland-shm.c#L514
fn sigbusHandler(sig: i32, info: *const os.siginfo_t, data: ?*const c_void) callconv(.C) void {
    SIGBUS_ERROR = true;
    _ = linux.mmap(CURRENT_POOL_ADDRESS, CURRENT_POOL_SIZE, linux.PROT_READ | linux.PROT_WRITE, linux.MAP_FIXED | linux.MAP_PRIVATE | linux.MAP_ANONYMOUS, -1, 0);
}
