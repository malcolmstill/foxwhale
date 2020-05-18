const std = @import("std");
const prot = @import("protocols.zig");
const Client = @import("client.zig").Client;
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

fn get_pointer(context: *Context, wl_seat: Object, new_id: u32) anyerror!void {
    context.client.wl_pointer_id = new_id;
    var wl_pointer = prot.new_wl_pointer(new_id, context, 0);
    try context.register(wl_pointer);
}

fn get_keyboard(context: *Context, wl_seat: Object, new_id: u32) anyerror!void {
    context.client.wl_keyboard_id = new_id;
    var wl_keyboard = prot.new_wl_keyboard(new_id, context, 0);
    try context.register(wl_keyboard);
}

pub fn init() void {
    prot.WL_SEAT.get_pointer = get_pointer;
    prot.WL_SEAT.get_keyboard = get_keyboard;
}