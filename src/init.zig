const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;

const wl_compositor_impl = @import("wl_compositor.zig");
const wl_seat_impl = @import("wl_seat.zig");
const wl_shm_pool_impl = @import("wl_shm_pool.zig");
const wl_shm_buffer_impl = @import("wl_shm_buffer.zig");
const wl_surface_impl = @import("wl_surface.zig");
const xdg_base_impl = @import("xdg_base.zig");
const xdg_surface_impl = @import("xdg_surface.zig");
const xdg_toplevel_impl = @import("xdg_toplevel.zig");

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
    wl.WL_REGISTRY.bind = bind;

    wl_compositor_impl.init();
    wl_seat_impl.init();
    wl_shm_pool_impl.init();
    wl_shm_buffer_impl.init();
    wl_surface_impl.init();

    xdg_base_impl.init();
    xdg_surface_impl.init();
    xdg_toplevel_impl.init();
}

fn sync(context: *Context, display: Object, new_id: u32) anyerror!void {
    std.debug.warn("sync with id {}\n", .{new_id});

    var callback = wl.new_wl_callback(new_id, display.context, 0);
    try wl.wl_callback_send_done(callback, @intCast(u32, std.time.timestamp()));
    try wl.wl_display_send_delete_id(display, callback.id);
}

fn get_registry(context: *Context, display: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_registry with id {}\n", .{new_id});

    var registry = wl.new_wl_registry(new_id, context, 0);

    try wl.wl_registry_send_global(registry, 1, "wl_compositor\x00", 4);
    try wl.wl_registry_send_global(registry, 2, "wl_subcompositor\x00", 1);
    try wl.wl_registry_send_global(registry, 3, "wl_seat\x00", 4);
    try wl.wl_registry_send_global(registry, 4, "xdg_wm_base\x00", 1);
    try wl.wl_registry_send_global(registry, 5, "wl_output\x00", 2);
    try wl.wl_registry_send_global(registry, 6, "wl_data_device_manager\x00", 3);
    try wl.wl_registry_send_global(registry, 7, "wl_shell\x00", 1);
    try wl.wl_registry_send_global(registry, 8, "wl_shm\x00", 1);
    try wl.wl_registry_send_global(registry, 9, "zxdg_decoration_manager_v1\x00", 1);
    try wl.wl_registry_send_global(registry, 10, "zwp_linux_dmabuf_v1\x00", 3);

    try context.register(registry);
}

fn bind(context: *Context, registry: Object, name: u32, name_string: []u8, version: u32, new_id: u32) anyerror!void {
    std.debug.warn("bind for {} ({}) with id {} at version {}\n", .{name_string, name, new_id, version});

    switch (name) {
        1 => {
            var wl_compositor = wl.new_wl_compositor(new_id, context, 0);
            wl_compositor.version = version;
            context.client.wl_compositor_id = wl_compositor.id;

            try context.register(wl_compositor);
        },
        2 => {
            var wl_subcompositor = wl.new_wl_subcompositor(new_id, context, 0);
            wl_subcompositor.version = version;
            context.client.wl_subcompositor_id = wl_subcompositor.id;

            try context.register(wl_subcompositor);
        },
        3 => {
            if (context.client.wl_seat_id != null) {
                return;
            }

            var wl_seat = wl.new_wl_seat(new_id, context, 0);
            wl_seat.version = version;
            try wl.wl_seat_send_capabilities(wl_seat, @enumToInt(wl.wl_seat_capability.pointer) | @enumToInt(wl.wl_seat_capability.keyboard));
            context.client.wl_seat_id = wl_seat.id;

            try context.register(wl_seat);
        },
        4 => {
            var xdg_wm_base = wl.new_xdg_wm_base(new_id, context, 0);
            xdg_wm_base.version = version;
            context.client.xdg_wm_base_id = xdg_wm_base.id;

            try context.register(xdg_wm_base);
        },
        5 => {
            var wl_output = wl.new_wl_output(new_id, context, 0);
            wl_output.version = version;
            context.client.wl_output_id = wl_output.id;

            try wl.wl_output_send_geometry(wl_output, 0, 0, 267, 200, @enumToInt(wl.wl_output_subpixel.none), "unknown", "unknown", @enumToInt(wl.wl_output_transform.normal));
            try wl.wl_output_send_mode(wl_output, @enumToInt(wl.wl_output_mode.current), 640, 480, 60000);
            try wl.wl_output_send_scale(wl_output, 1);
            try wl.wl_output_send_done(wl_output);

            try context.register(wl_output);
        },
        6 => {},
        7 => {},
        8 => {
            var wl_shm = wl.new_wl_shm(new_id, context, 0);
            wl_shm.version = version;
            context.client.wl_shm_id = wl_shm.id;

            try wl.wl_shm_send_format(wl_shm, @enumToInt(wl.wl_shm_format.argb8888));
            try wl.wl_shm_send_format(wl_shm, @enumToInt(wl.wl_shm_format.xrgb8888));

            try context.register(wl_shm);
        },
        9 => {},
        10 => {},
        else => {},
    }
}
