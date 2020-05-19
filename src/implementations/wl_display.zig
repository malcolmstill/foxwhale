const std = @import("std");
const prot = @import("../protocols.zig");
const out = @import("../output.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;

fn sync(context: *Context, wl_display: Object, new_id: u32) anyerror!void {
    // std.debug.warn("sync with id {}\n", .{new_id});

    var wl_callback = prot.new_wl_callback(new_id, context, 0);
    try prot.wl_callback_send_done(wl_callback, context.client.nextSerial());
    try prot.wl_display_send_delete_id(wl_display, new_id);
}

fn get_registry(context: *Context, wl_display: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_registry with id {}\n", .{new_id});

    var wl_registry = prot.new_wl_registry(new_id, context, 0);
    context.client.wl_registry_id = new_id;

    try prot.wl_registry_send_global(wl_registry, 1, "wl_compositor\x00", 4);
    try prot.wl_registry_send_global(wl_registry, 2, "wl_subcompositor\x00", 1);
    try prot.wl_registry_send_global(wl_registry, 3, "wl_seat\x00", 4);
    try prot.wl_registry_send_global(wl_registry, 4, "xdg_wm_base\x00", 1);

    var output_base: u32 = out.OUTPUT_BASE;
    var it = out.OUTPUTS.iterator();
    while(it.next()) |output| {
        try prot.wl_registry_send_global(wl_registry, output_base, "wl_output\x00", 2);
        output_base += 1;
    }

    try prot.wl_registry_send_global(wl_registry, 6, "wl_data_device_manager\x00", 3);
    try prot.wl_registry_send_global(wl_registry, 7, "wl_shell\x00", 1);
    try prot.wl_registry_send_global(wl_registry, 8, "wl_shm\x00", 1);
    // try prot.wl_registry_send_global(wl_registry, 9, "zxdg_decoration_manager_v1\x00", 1);
    // try prot.wl_registry_send_global(wl_registry, 10, "zwp_linux_dmabuf_v1\x00", 3);
    try prot.wl_registry_send_global(wl_registry, 11, "fw_control\x00", 1);

    try context.register(wl_registry);
}

pub fn init() void {
    prot.WL_DISPLAY.sync = sync;
    prot.WL_DISPLAY.get_registry = get_registry;
}