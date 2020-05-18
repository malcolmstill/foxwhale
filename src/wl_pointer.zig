const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;
const Window = @import("window.zig").Window;
const Cursor = @import("window.zig").Cursor;
const compositor = @import("compositor.zig");

fn set_cursor(context: *Context, wl_pointer: Object, serial: u32, optional_wl_surface: ?Object, hotspot_x: i32, hotspot_y: i32) anyerror!void {
    if (optional_wl_surface) |wl_surface| {
        var cursor_window = @intToPtr(*Window, wl_surface.container);
        cursor_window.cursor = Cursor {
            .hotspot_x = hotspot_x,
            .hotspot_y = hotspot_y,
        };

        compositor.COMPOSITOR.cursor = wl_surface.id;
    } else {
        compositor.COMPOSITOR.cursor = null;
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