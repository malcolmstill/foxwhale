//
// In wayland we can multiple types of buffers. Typically,
// we may have a shm buffer, but we also might have a dmabuf.
// Let's have a uniform way to represent these with a buffer
// union type.
//
const ShmBuffer = @import("shm_buffer.zig").ShmBuffer;
const DmaBuffer = @import("dmabuf.zig").DmaBuffer;
const Client = @import("client.zig").Client;
const Stalloc = @import("stalloc.zig").Stalloc;

const MAX_BUFFERS = 2048;
pub var BUFFERS: Stalloc(Client, Buffer, 2048) = undefined;

pub fn newBuffer(client: *Client) !*Buffer {
    var buffer = try BUFFERS.new(client);
    return buffer;
}

pub const Buffer = union(enum) {
    Shm: ShmBuffer,
    Dma: DmaBuffer,

    const Self = @This();

    pub fn deinit(buffer: *Buffer) !void {
        switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| shm_buffer.deinit(),
            Buffer.Dma => |*dmabuf| dmabuf.deinit(),
            else => unreachable,
        }
    }

    pub fn beginAccess(buffer: *Buffer) void {
        switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| shm_buffer.beginAccess(),
            Buffer.Dma => |*dmabuf| dmabuf.beginAccess(),
            else => unreachable,
        }
    }

    pub fn endAccess(buffer: *Buffer) !void {
        return switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| shm_buffer.endAccess(),
            Buffer.Dma => |*dmabuf| dmabuf.endAccess(),
            else => unreachable,
        };
    }    

    pub fn makeTexture(buffer: *Buffer) anyerror!u32 {
        return switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| shm_buffer.makeTexture(),
            Buffer.Dma => |*dmabuf| dmabuf.makeTexture(),
            else => unreachable,
        };
    }    

    pub fn width(buffer: *Buffer) i32 {
        switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| return shm_buffer.width,
            Buffer.Dma => |*dmabuf| return dmabuf.width,
            else => unreachable,
        }
    }

    pub fn height(buffer: *Buffer) i32 {
        switch (buffer.*) {
            Buffer.Shm => |*shm_buffer| return shm_buffer.height,
            Buffer.Dma => |*dmabuf| return dmabuf.height,
            else => unreachable,
        }
    }
};

pub fn releaseBuffers(client: *Client) !void {
    try BUFFERS.releaseBelongingTo(client);
}