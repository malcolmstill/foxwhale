const std = @import("std");
const prot = @import("../protocols.zig");
const Client = @import("../client.zig").Client;
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const compositor = @import("../compositor.zig");

fn get_pointer(context: *Context, wl_seat: Object, new_id: u32) anyerror!void {
    context.client.wl_pointer_id = new_id;
    var wl_pointer = prot.new_wl_pointer(new_id, context, 0);
    try context.register(wl_pointer);
}

fn get_keyboard(context: *Context, wl_seat: Object, new_id: u32) anyerror!void {
    if (context.client.wl_seat_id) |wl_seat_id| {
        if (wl_seat_id == wl_seat.id) {
            context.client.wl_keyboard_id = new_id;
        }
    }

    var wl_keyboard = prot.new_wl_keyboard(new_id, context, 0);

    if (compositor.COMPOSITOR.xkb) |*xkb| {
        var fd_size = try xkb.getKeymap();
        var format: u32 = @enumToInt(prot.wl_keyboard_keymap_format.xkb_v1);

        try prot.wl_keyboard_send_keymap(wl_keyboard, format, fd_size.fd, @intCast(u32, fd_size.size));

        if (wl_seat.version >= 4) {
            try prot.wl_keyboard_send_repeat_info(wl_keyboard, 1, 2000);
        }
    }

    try context.register(wl_keyboard);
}

pub fn init() void {
    prot.WL_SEAT.get_pointer = get_pointer;
    prot.WL_SEAT.get_keyboard = get_keyboard;
}
