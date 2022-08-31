fn destroy(_: *Context, _: Object) anyerror!void {
    // return error.DebugFunctionNotImplemented;
}

fn add(_: *Context, zwp_linux_buffer_params: Object, fd: i32, plane_idx: u32, offset: u32, stride: u32, modifier_hi: u32, modifier_lo: u32) anyerror!void {
    const params = @intToPtr(*Params, zwp_linux_buffer_params.container);
    try params.planes.writeItem(Plane{
        .fd = fd,
        .plane_idx = plane_idx,
        .offset = offset,
        .stride = stride,
        .modifier_hi = modifier_hi,
        .modifier_lo = modifier_lo,
    });
}

fn create(
    context: *Context,
    zwp_linux_buffer_params: Object,
    width: i32,
    height: i32,
    format: u32,
    _: u32, // flags
) anyerror!void {
    const params = @intToPtr(*Params, zwp_linux_buffer_params.container);
    _ = context.client.nextServerId();
    var attribs: [49]isize = [_]isize{c.EGL_NONE} ** 49;
    var i: usize = 0;

    // TODO: this is currently wrong because it only references PLANE0
    // see: https://github.com/wayland-project/weston/blob/ad41ad968afbab4c56cb81becf79bb47d575d388/libweston/renderer-gl/gl-renderer.c#L1930
    while (params.planes.readItem()) |plane| {
        attribs[i] = c.EGL_WIDTH;
        i += 1;
        attribs[i] = width;
        i += 1;
        attribs[i] = c.EGL_HEIGHT;
        i += 1;
        attribs[i] = height;
        i += 1;
        attribs[i] = c.EGL_LINUX_DRM_FOURCC_EXT;
        i += 1;
        attribs[i] = @intCast(i32, format);
        i += 1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_FD_EXT;
        i += 1;
        attribs[i] = plane.fd;
        i += 1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_OFFSET_EXT;
        i += 1;
        attribs[i] = @intCast(i32, plane.offset);
        i += 1;
        attribs[i] = c.EGL_DMA_BUF_PLANE0_PITCH_EXT;
        i += 1;
        attribs[i] = @intCast(i32, plane.stride);
        i += 1;
    }

    // switch (main.OUTPUT.backend) {
    //     .DRM => |drm| {
    //         const optional_image = c.eglCreateImage(drm.egl.display, null, c.EGL_LINUX_DMA_BUF_EXT, null, &attribs[0]);

    //         if (optional_image) |image| {
    //             const buffer = try dmabuf.newDmaBuffer(context.client, zwp_linux_buffer_params.id, next_id, width, height, format, image);
    //             const wl_buffer = prot.new_wl_buffer(next_id, context, @ptrToInt(buffer));
    //             try prot.zwp_linux_buffer_params_v1_send_created(zwp_linux_buffer_params, next_id);
    //             try context.register(wl_buffer);
    //         }
    //     },
    //     else => {
    //         try prot.zwp_linux_buffer_params_v1_send_failed(zwp_linux_buffer_params);
    //     },
    // }
}

fn create_immed(
    _: *Context,
    _: Object, // zwp_linux_buffer_params
    _: u32, // buffer_id
    _: i32, // width
    _: i32, // height
    _: u32, // format
    _: u32, // flags
) anyerror!void {
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
const main = @import("../main.zig");
const Params = @import("../dmabuf_params.zig").Params;
const Plane = @import("../dmabuf_params.zig").Plane;
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;

const c = @cImport({
    @cInclude("EGL/egl.h");
    @cInclude("EGL/eglext.h");
});
