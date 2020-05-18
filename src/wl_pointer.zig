const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

fn set_cursor(context: *Context, wl_pointer: Object, serial: u32, surface: ?Object, hotspot_x: i32, hotspot_y: i32) anyerror!void {
    
}

fn release(context: *Context, wl_pointer: Object) anyerror!void {

}

pub fn init() void {
    prot.WL_POINTER = prot.wl_pointer_interface{
        .set_cursor = set_cursor,
        .release = release,
    };
}