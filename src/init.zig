const std = @import("std");
const wl = @import("wl/protocols.zig");
const Object = @import("wl/context.zig").Object;

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
    wl.WL_REGISTRY.bind = bind;
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

    wl.wl_registry_send_global(registry, 1, "wl_compositor\x00", 4);
    wl.wl_registry_send_global(registry, 2, "wl_subcompositor\x00", 1);
    wl.wl_registry_send_global(registry, 3, "wl_seat\x00", 4);
    wl.wl_registry_send_global(registry, 4, "xdg_wm_base\x00", 1);
    wl.wl_registry_send_global(registry, 5, "wl_output\x00", 2);
    wl.wl_registry_send_global(registry, 6, "wl_data_device_manager\x00", 3);
    wl.wl_registry_send_global(registry, 7, "wl_shell\x00", 1);
    wl.wl_registry_send_global(registry, 8, "wl_shm\x00", 1);
    wl.wl_registry_send_global(registry, 9, "zxdg_decoration_manager_v1\x00", 1);
    wl.wl_registry_send_global(registry, 10, "zwp_linux_dmabuf_v1\x00", 3);
}

fn bind(registry: Object, name: u32, name_string: []u8, version: u32, new_id: u32) void {
    std.debug.warn("bind for {} ({}) with id {} at version {}\n", .{name_string, name, new_id, version});

    switch (name) {
        1 => {
            var compositor = wl.new_wl_compositor(registry.context, new_id);

            if (registry.context.objects.get(compositor.id)) |c| {
                c.value.version = version;
            }

            registry.context.client.compositor = compositor.id;
        },
        2 => {
            var subcompositor = wl.new_wl_subcompositor(registry.context, new_id);

            if (registry.context.objects.get(subcompositor.id)) |s| {
                s.value.version = version;
            }

            registry.context.client.subcompositor = subcompositor.id;},
        3 => {
            if (registry.context.client.seat == null) {
                var seat = wl.new_wl_seat(registry.context, new_id);

                if (registry.context.objects.get(seat.id)) |s| {
                    s.value.version = version;
                    wl.wl_seat_send_capabilities(s.value, @enumToInt(wl.wl_seat_capability.pointer) | @enumToInt(wl.wl_seat_capability.keyboard));
                }

                registry.context.client.seat = seat.id;
            }
        },
        4 => {},
        5 => {},
        6 => {},
        7 => {},
        8 => {},
        9 => {},
        10 => {},
        else => {},
    }
}