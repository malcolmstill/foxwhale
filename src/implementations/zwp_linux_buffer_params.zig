fn destroy(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn add(context: *Context, zwp_linux_buffer_params: Object, fd: i32, plane_idx: u32, offset: u32, stride: u32, modifier_hi: u32, modifier_lo: u32) anyerror!void {
    var params = @intToPtr(*Params, zwp_linux_buffer_params.container);
    try params.planes.writeItem(Plane{
        .fd = fd,
        .plane_idx = plane_idx,
        .offset = offset,
        .stride = stride,
        .modifier_hi = modifier_hi,
        .modifier_lo = modifier_lo,
    });
}

fn create(context: *Context, zwp_linux_buffer_params: Object, width: i32, height: i32, format: u32, flags: u32) anyerror!void {
    var params = @intToPtr(*Params, zwp_linux_buffer_params.container);
    var next_id: usize = 0;
    var attribs: [49]i32 = [_]i32{c.EGL_NONE} ** 49;
    var i: usize = 0;

    while(params.planes.readItem()) |plane| {
        attribs[i] = c.EGL_WIDTH; i+=1;
        attribs[i] = width; i+=1;
        attribs[i] = c.EGL_HEIGHT; i+=1;
        attribs[i] = height; i+=1;
        attribs[i] = c.EGL_LINUX_DRM_FOURCC_EXT; i+=1;
        attribs[i] = @intCast(i32, format); i+=1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_FD_EXT; i+=1;
        attribs[i] = plane.fd; i+=1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_OFFSET_EXT; i+=1;
        attribs[i] = @intCast(i32, plane.offset); i+=1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_PITCH_EXT; i+=1;
        attribs[i] = @intCast(i32, plane.stride); i+=1;
    } else |err| {

    }
}

fn create_immed(context: *Context, zwp_linux_buffer_params: Object, buffer_id: u32, width: i32, height: i32, format: u32, flags: u32) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub fn init() void {
    prot.ZWP_LINUX_BUFFER_PARAMS_V1 = prot.zwp_linux_buffer_params_v1_interface{
        .destroy = destroy,
        .add = add,
        .create = create,
        .create_immed = create_immed,
    };
}

const prot = @import("../protocols.zig");
const dmabuf = @import("../dmabuf.zig");
const Params = @import("../dmabuf.zig").Params;
const Plane = @import("../dmabuf.zig").Plane;
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;

const c = @cImport({
    @cInclude("EGL/egl.h");
    @cInclude("EGL/eglext.h");
});