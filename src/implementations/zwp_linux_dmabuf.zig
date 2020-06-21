fn destroy(context: *Context, zwp_linux_dmabuf: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, zwp_linux_dmabuf.id);
    try context.unregister(zwp_linux_dmabuf);
}

fn create_params(context: *Context, zwp_linux_dmabuf: Object, new_id: u32) anyerror!void {
    var params = try dmabuf.newParams(context.client, new_id);
    var zwp_linux_dmabuf_params = prot.new_zwp_linux_buffer_params_v1(new_id, context, @ptrToInt(params));
    try context.register(zwp_linux_dmabuf_params);
}

pub fn init() void {
    prot.ZWP_LINUX_DMABUF_V1 = prot.zwp_linux_dmabuf_v1_interface{
        .destroy = destroy,
        .create_params = create_params,
    };
}

const prot = @import("../protocols.zig");
const dmabuf = @import("../dmabuf.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;