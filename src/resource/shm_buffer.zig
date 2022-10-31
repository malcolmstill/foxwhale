const std = @import("std");
const linux = std.os.linux;
const os = std.os;
const Renderer = @import("../renderer.zig").Renderer;
const Object = @import("../client.zig").Object;
const Context = @import("../client.zig").Context;
const Client = @import("../client.zig").Client;
const ShmPool = @import("shm_pool.zig").ShmPool;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;

const wl = @import("../client.zig").wl;

pub const ShmBuffer = struct {
    client: *Client,
    wl_buffer: wl.WlBuffer,
    shm_pool: *ShmPool,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: wl.WlShm.Format,

    const Self = @This();

    pub fn init(client: *Client, shm_pool: *ShmPool, wl_buffer: wl.WlBuffer, offset: i32, width: i32, height: i32, stride: i32, format: wl.WlShm.Format) ShmBuffer {
        shm_pool.incrementRefCount();
        return ShmBuffer{
            .client = client,
            .shm_pool = shm_pool,
            .wl_buffer = wl_buffer,
            .offset = offset,
            .width = width,
            .height = height,
            .stride = stride,
            .format = format,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn beginAccess(self: *Self) void {
        CURRENT_POOL_ADDRESS = self.shm_pool.data.ptr;
        CURRENT_POOL_SIZE = self.shm_pool.data.len;
        _ = linux.sigaction(os.SIG.BUS, &sigbus_handler_action, null);
    }

    pub fn endAccess(_: *Self) !void {
        defer {
            SIGBUS_ERROR = false;
            _ = linux.sigaction(os.SIG.BUS, &sigbus_handler_reset, null);
        }
        if (SIGBUS_ERROR) {
            return error.ClientSigbusd;
        }
    }

    pub fn makeTexture(self: *Self) !u32 {
        var offset = @intCast(usize, self.offset);
        return Renderer.makeTexture(self.width, self.height, self.stride, @enumToInt(self.format), self.shm_pool.data[offset..]);
    }
};

var SIGBUS_ERROR = false;
var CURRENT_POOL_ADDRESS: [*]align(4096) u8 = undefined;
var CURRENT_POOL_SIZE: usize = 0;

const sigbus_handler_action = os.Sigaction{
    .handler = .{ .sigaction = sigbusHandler },
    .mask = linux.empty_sigset,
    .flags = linux.SA.RESETHAND,
};

const sigbus_handler_reset = os.Sigaction{
    .handler = .{ .sigaction = null },
    .mask = linux.empty_sigset,
    .flags = linux.SA.RESETHAND,
};

// libwayland uses a cool trick of mmap'ing some new data underneath (i.e. at the
// same address as) the SHM buffer, essentially throwing away the SHM'ness of the
// memory and guaranteeing that when the code is retried that SIGBUS will not be
// raised.
// See: https://github.com/wayland-project/wayland/blob/11623e8fddb924c7ae317f2eabac23785ae5e8d5/src/wayland-shm.c#L514
fn sigbusHandler(
    _: i32, // sig
    _: *const os.siginfo_t, // info
    _: ?*const anyopaque, // data
) callconv(.C) void {
    SIGBUS_ERROR = true;
    _ = linux.mmap(CURRENT_POOL_ADDRESS, CURRENT_POOL_SIZE, linux.PROT.READ | linux.PROT.WRITE, linux.MAP.FIXED | linux.MAP.PRIVATE | linux.MAP.ANONYMOUS, -1, 0);
}
