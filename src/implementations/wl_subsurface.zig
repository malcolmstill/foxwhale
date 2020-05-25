const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;

fn destroy(context: *Context, wl_subsurface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    window.wl_subsurface_id = null;
    try prot.wl_display_send_delete_id(context.client.wl_display, wl_subsurface.id);
    try context.unregister(wl_subsurface);
}

fn set_position(context: *Context, wl_subsurface: Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);

    window.pending().x = x;
    window.pending().y = y;
}

fn place_above(context: *Context, wl_subsurface: Object, wl_surface_sibling: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    var sibling = @intToPtr(*Window, wl_surface_sibling.container);

    window.placeAbove(sibling);
}

fn place_below(context: *Context, wl_subsurface: Object, wl_surface_sibling: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    var sibling = @intToPtr(*Window, wl_surface_sibling.container);

    window.placeBelow(sibling);
}

fn set_sync(context: *Context, wl_subsurface: Object) anyerror!void { 
    var window = @intToPtr(*Window, wl_subsurface.container);
    window.synchronized = true;
}

fn set_desync(context: *Context, wl_subsurface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    window.synchronized = false;
}

pub fn init() void {
    prot.WL_SUBSURFACE = prot.wl_subsurface_interface{
        .destroy = destroy,
        .set_position = set_position,
        .place_above = place_above,
        .place_below = place_below,
        .set_sync = set_sync,
        .set_desync = set_desync,
    };
}