const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;
const Window = @import("window.zig").Window;

fn destroy(context: *Context, object: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn set_position(context: *Context, wl_subsurface: Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);

    window.pending().x = x;
    window.pending().y = y;
}

fn place_above(context: *Context, object: Object, sibling: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn place_below(context: *Context, object: Object, sibling: Object) anyerror!void {
    return error.DebugFunctionNotImplemented;
}

fn set_sync(context: *Context, wl_subsurface: Object) anyerror!void { 
    var window = @intToPtr(*Window, wl_subsurface.container);
    window.pending().sync = true;
}

fn set_desync(context: *Context, wl_subsurface: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    window.pending().sync = false;
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