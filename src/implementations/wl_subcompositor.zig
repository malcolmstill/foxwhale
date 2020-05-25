const std = @import("std");
const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;

fn destroy(context: *Context, wl_subcompositor: Object) anyerror!void {
    context.client.wl_subcompositor_id = null;
    try prot.wl_display_send_delete_id(context.client.wl_display, wl_subcompositor.id);
    try context.unregister(wl_subcompositor);
}

fn get_subsurface(context: *Context, wl_subcompositor: Object, new_id: u32, wl_surface_child: Object, wl_surface_parent: Object) anyerror!void {
    var child = @intToPtr(*Window, wl_surface_child.container);
    var parent = @intToPtr(*Window, wl_surface_parent.container);

    child.wl_subsurface_id = new_id;
    child.parent = parent;
    child.synchronized = true;

    child.detach();
    child.placeAbove(parent);

    var wl_subsurface_child = prot.new_wl_subsurface(new_id, context, @ptrToInt(child));
    try context.register(wl_subsurface_child);
}

pub fn init() void {
    prot.WL_SUBCOMPOSITOR = prot.wl_subcompositor_interface{
        .destroy = destroy,
        .get_subsurface = get_subsurface,
    };
}