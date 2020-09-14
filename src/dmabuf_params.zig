

pub var PARAMS: Stalloc(Client, Params, 1024) = undefined;
pub const PlaneFifo = LinearFifo(Plane, LinearFifoBufferType{ .Static = 4 });

pub const Params = struct {
    zwp_linux_dmabuf_params_id: u32,
    planes: PlaneFifo,
};

pub fn newParams(client: *Client, zwp_linux_dmabuf_params_id: u32) !*Params {
    var params = try PARAMS.new(client);
    params.zwp_linux_dmabuf_params_id = zwp_linux_dmabuf_params_id;

    return params;
}

pub fn releaseParams(client: *Client) !void {
    try PARAMS.releaseBelongingTo(client);
}

pub const Plane = struct {
    fd: i32,
    plane_idx: u32,
    offset: u32,
    stride: u32,
    modifier_hi: u32,
    modifier_lo: u32,
};

pub const DRM_FORMAT_XRGB8888 = c.DRM_FORMAT_XRGB8888;
pub const DRM_FORMAT_XBGR8888 = c.DRM_FORMAT_XBGR8888;

const std = @import("std");
const Stalloc = @import("stalloc.zig").Stalloc;
const Client = @import("client.zig").Client;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;

const c = @cImport({
    @cInclude("drm/drm_fourcc.h");
});