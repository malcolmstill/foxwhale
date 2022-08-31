const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;
const ClientCursor = @import("../cursor.zig").ClientCursor;
const views = @import("../view.zig");

fn set_cursor(
    context: *Context,
    _: Object, // wl_pointer
    _: u32, // serial
    optional_wl_surface: ?Object,
    hotspot_x: i32,
    hotspot_y: i32,
) anyerror!void {
    const current_view = context.client.compositor.current_view orelse return;
    const pointer_window = current_view.pointer_window orelse return;
    if (&pointer_window.client.context != context) return;

    if (optional_wl_surface) |wl_surface| {
        const cursor_window = @intToPtr(*Window, wl_surface.container);

        cursor_window.pending().x = -hotspot_x;
        cursor_window.pending().y = -hotspot_y;
        cursor_window.current().x = -hotspot_x;
        cursor_window.current().y = -hotspot_y;

        context.client.compositor.client_cursor = ClientCursor{ .CursorWindow = cursor_window };
    } else {
        context.client.compositor.client_cursor = ClientCursor.CursorHidden;
    }
}

fn release(
    _: *Context,
    _: Object, // wl_pointer
) anyerror!void {}

pub fn init() void {
    prot.WL_POINTER = prot.wl_pointer_interface{
        .set_cursor = set_cursor,
        .release = release,
    };
}
