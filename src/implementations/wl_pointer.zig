const prot = @import("../protocols.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;
const ClientCursor = @import("../cursor.zig").ClientCursor;
const views = @import("../view.zig");
const compositor = @import("../compositor.zig");

fn set_cursor(context: *Context, wl_pointer: Object, serial: u32, optional_wl_surface: ?Object, hotspot_x: i32, hotspot_y: i32) anyerror!void {
    if (views.CURRENT_VIEW.pointer_window) |pointer_window| {
        if(&pointer_window.client.context == context) {
            if (optional_wl_surface) |wl_surface| {
                var cursor_window = @intToPtr(*Window, wl_surface.container);

                cursor_window.pending().x = -hotspot_x;
                cursor_window.pending().y = -hotspot_y;
                cursor_window.current().x = -hotspot_x;
                cursor_window.current().y = -hotspot_y;

                compositor.COMPOSITOR.client_cursor = ClientCursor{ .CursorWindow = cursor_window };
            } else {
                compositor.COMPOSITOR.client_cursor = ClientCursor.CursorHidden;
            }
        }
    }
}

fn release(context: *Context, wl_pointer: Object) anyerror!void {

}

pub fn init() void {
    prot.WL_POINTER = prot.wl_pointer_interface{
        .set_cursor = set_cursor,
        .release = release,
    };
}