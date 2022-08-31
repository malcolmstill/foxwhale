const std = @import("std");
const prot = @import("../protocols.zig");
const compositor = @import("../compositor.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Window = @import("../window.zig").Window;
const XdgConfiguration = @import("../window.zig").XdgConfiguration;
const Move = @import("../move.zig").Move;
const Resize = @import("../resize.zig").Resize;

fn destroy(context: *Context, xdg_popup: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, xdg_popup.id);
    try context.unregister(xdg_popup);
}

fn grab(
    _: *Context,
    _: Object, // xdg_popup
    _: Object, // seat
    _: u32, // serial
) anyerror!void {
    // return error.DebugFunctionNotImplemented;
}

fn reposition(
    _: *Context,
    _: Object,
    _: Object, // positioner
    _: u32, // token
) anyerror!void {
    // return error.DebugFunctionNotImplemented;
}

pub fn init() void {
    prot.XDG_POPUP = prot.xdg_popup_interface{
        .destroy = destroy,
        .grab = grab,
        .reposition = reposition,
    };
}
