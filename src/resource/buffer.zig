//
// In wayland we can multiple types of buffers. Typically,
// we may have a shm buffer, but we also might have a dmabuf.
// Let's have a uniform way to represent these with a buffer
// union type.
//
const ShmBuffer = @import("shm_buffer.zig").ShmBuffer;
const DmaBuffer = @import("dmabuf.zig").DmaBuffer;

pub const Buffer = union(enum) {
    shm: ShmBuffer,
    dma: DmaBuffer,

    const Self = @This();

    pub fn deinit(buffer: *Buffer) !void {
        switch (buffer.*) {
            .shm => |*shm_buffer| shm_buffer.deinit(),
            .dma => |*dmabuf| dmabuf.deinit(),
        }
    }

    pub fn beginAccess(buffer: *Buffer) void {
        switch (buffer.*) {
            .shm => |*shm_buffer| shm_buffer.beginAccess(),
            .dma => |*dmabuf| dmabuf.beginAccess(),
        }
    }

    pub fn endAccess(buffer: *Buffer) !void {
        return switch (buffer.*) {
            .shm => |*shm_buffer| shm_buffer.endAccess(),
            .dma => |*dmabuf| dmabuf.endAccess(),
        };
    }

    pub fn makeTexture(buffer: *Buffer) anyerror!u32 {
        return switch (buffer.*) {
            .shm => |*shm_buffer| shm_buffer.makeTexture(),
            .dma => |*dmabuf| dmabuf.makeTexture(),
        };
    }

    pub fn width(buffer: *Buffer) i32 {
        switch (buffer.*) {
            .shm => |*shm_buffer| return shm_buffer.width,
            .dma => |*dmabuf| return dmabuf.width,
        }
    }

    pub fn height(buffer: *Buffer) i32 {
        switch (buffer.*) {
            .shm => |*shm_buffer| return shm_buffer.height,
            .dma => |*dmabuf| return dmabuf.height,
        }
    }
};
