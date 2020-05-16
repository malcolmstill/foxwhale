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

fn place_above(context: *Context, wl_subsurface: Object, wl_surface_sibling: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    var sibling = @intToPtr(*Window, wl_surface_sibling.container);

    // 1. Detach window
    if (window.current().prev) |prev| {
        prev.pending().next = window.current().next;
    }

    if (window.current().next) |next| {
        next.pending().prev = window.current().prev;
    }

    // 2. window.next may end up being null
    window.pending().next = null;

    // 3. window.prev will definitely be sibling
    window.pending().prev = sibling;

    // 4. if sibling has next, then next.prev is window and window.next is sibling.next
    if (sibling.current().next) |next| {
        next.pending().prev = window;
        window.pending().next = sibling.current().next;
    }

    // 5. sibling.next becomes window
    sibling.pending().next = window;
}

fn place_below(context: *Context, wl_subsurface: Object, wl_surface_sibling: Object) anyerror!void {
    var window = @intToPtr(*Window, wl_subsurface.container);
    var sibling = @intToPtr(*Window, wl_surface_sibling.container);

    // 1. Detach window
    if (window.current().prev) |prev| {
        prev.pending().next = window.current().next;
    }

    if (window.current().next) |next| {
        next.pending().prev = window.current().prev;
    }

    // 2. window.prev may end up being null
    window.pending().prev = null;

    // 3. window.next will definitely be sibling
    window.pending().next = sibling;

    // 4. if sibling has prev, then prev.next is window and window.prev is sibling.prev
    if (sibling.current().prev) |prev| {
        prev.pending().next = window;
        window.pending().prev = sibling.current().prev;
    }

    // 5. sibling.prev becomes window
    sibling.pending().prev = window;
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