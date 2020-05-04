const std = @import("std");
const wl = @import("wl/wayland.zig");
const Object = @import("wl/context.zig").Object;

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
}

fn sync(object: Object, new_id: u32) void {
    std.debug.warn("sync with id {}\n", .{new_id});
    var callback = wl.new_wl_callback(object.context, new_id);
    wl.wl_callback_send_done(callback, 0);
    var x = object.context.unregister(callback);
    wl.wl_display_send_delete_id(object, callback.id);
}

fn get_registry(object: Object, new_id: u32) void {
    std.debug.warn("get_registry with id {}\n", .{new_id});
    var registry = wl.new_wl_registry(object.context, new_id);

    var name: []const u8 = "wl_compositor\x00";
    // var name = &[_]namex;
    wl.wl_registry_send_global(registry, 1, name[0..name.len], 4);
    // std.debug.warn("tx_buf after wl_registry_send_global {x}\n", .{registry.context.tx_buf});
}
