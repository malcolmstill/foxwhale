fn destroy(context: *Context, zwp_linux_dmabuf: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, zwp_linux_dmabuf.id);
    try context.unregister(zwp_linux_dmabuf);
}

fn create_params(
    context: *Context,
    _: Object, // zwp_linux_dmabuf
    new_id: u32,
) anyerror!void {
    const params = try dmabuf_params.newParams(context.client, new_id);
    const zwp_linux_dmabuf_params = prot.new_zwp_linux_buffer_params_v1(new_id, context, @ptrToInt(params));
    try context.register(zwp_linux_dmabuf_params);
}

fn get_default_feedback(
    _: *Context,
    _: Object,
    _: u32, // id
) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn get_surface_feedback(
    _: *Context,
    _: Object,
    _: u32, // id
    _: Object, // surface
) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

pub fn init() void {
    prot.ZWP_LINUX_DMABUF_V1 = prot.zwp_linux_dmabuf_v1_interface{
        .destroy = destroy,
        .create_params = create_params,
        .get_default_feedback = get_default_feedback,
        .get_surface_feedback = get_surface_feedback,
    };
}

const prot = @import("../protocols.zig");
const dmabuf_params = @import("../dmabuf_params.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
