const std = @import("std");
const prot = @import("protocols.zig");
const clients = @import("client.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

fn get_clients(context: *Context, fw_control: Object) anyerror!void {
    var it = clients.CLIENTS.iterator();
    while(it.next()) |client| {
        try prot.fw_control_send_client(fw_control, @intCast(u32, client.getIndexOf()));
    }
    try prot.fw_control_send_done(fw_control);
}

fn destroy(context: *Context, fw_control: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, fw_control.id);
    try context.unregister(fw_control);
}

pub fn init() void {
    prot.FW_CONTROL.get_clients = get_clients;
    prot.FW_CONTROL.destroy = destroy;
}
