const std = @import("std");
const linux = std.os.linux;
const Renderer = @import("renderer.zig").Renderer;
const Object = @import("client.zig").Object;
const Context = @import("client.zig").Context;
const Client = @import("client.zig").Client;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;

pub fn newDmaBuffer(client: *Client, params_id: u32, id: u32, width: i32, height: i32, format: u32, image: *anyopaque) !*Buffer {
    const dmabuf = DmaBuffer{
        .client = client,
        .width = width,
        .height = height,
        .format = format,
        .wl_buffer_id = id,
        .dmabuf_params_id = params_id,
        .image = image,
    };

    var buf = try buffer.newBuffer(client);
    buf.* = Buffer{ .Dma = dmabuf };

    return buf;
}

pub const DmaBuffer = struct {
    client: *Client,
    width: i32,
    height: i32,
    format: u32,
    dmabuf_params_id: u32,
    wl_buffer_id: u32,
    image: *anyopaque,

    const Self = @This();

    pub fn deinit(_: *Self) void {}

    pub fn beginAccess(_: *Self) void {}

    pub fn endAccess(_: *Self) !void {}

    pub fn makeTexture(self: *Self) !u32 {
        return Renderer.makeDmaTexture(self.image, self.width, self.height, self.format);
    }
};
