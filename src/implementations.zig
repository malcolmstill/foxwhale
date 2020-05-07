const std = @import("std");
const prot = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;

const wl_compositor_impl = @import("wl_compositor.zig");
const wl_display_impl = @import("wl_display.zig");
const wl_seat_impl = @import("wl_seat.zig");
const wl_shm_pool_impl = @import("wl_shm_pool.zig");
const wl_shm_buffer_impl = @import("wl_shm_buffer.zig");
const wl_surface_impl = @import("wl_surface.zig");
const xdg_base_impl = @import("xdg_base.zig");
const xdg_surface_impl = @import("xdg_surface.zig");
const xdg_toplevel_impl = @import("xdg_toplevel.zig");

pub fn init() void {
    prot.WL_REGISTRY.bind = bind;

    wl_compositor_impl.init();
    wl_display_impl.init();
    wl_seat_impl.init();
    wl_shm_pool_impl.init();
    wl_shm_buffer_impl.init();
    wl_surface_impl.init();

    xdg_base_impl.init();
    xdg_surface_impl.init();
    xdg_toplevel_impl.init();
}

fn bind(context: *Context, wl_registry: Object, name: u32, name_string: []u8, version: u32, new_id: u32) anyerror!void {
    std.debug.warn("bind for {} ({}) with id {} at version {}\n", .{name_string, name, new_id, version});

    switch (name) {
        1 => {
            var wl_compositor = prot.new_wl_compositor(new_id, context, 0);
            wl_compositor.version = version;
            context.client.wl_compositor_id = wl_compositor.id;

            try context.register(wl_compositor);
        },
        2 => {
            var wl_subcompositor = prot.new_wl_subcompositor(new_id, context, 0);
            wl_subcompositor.version = version;
            context.client.wl_subcompositor_id = wl_subcompositor.id;

            try context.register(wl_subcompositor);
        },
        3 => {
            if (context.client.wl_seat_id != null) {
                return;
            }

            var wl_seat = prot.new_wl_seat(new_id, context, 0);
            wl_seat.version = version;
            try prot.wl_seat_send_capabilities(wl_seat, @enumToInt(prot.wl_seat_capability.pointer) | @enumToInt(prot.wl_seat_capability.keyboard));
            context.client.wl_seat_id = wl_seat.id;

            try context.register(wl_seat);
        },
        4 => {
            var xdg_wm_base = prot.new_xdg_wm_base(new_id, context, 0);
            xdg_wm_base.version = version;
            context.client.xdg_wm_base_id = xdg_wm_base.id;

            try context.register(xdg_wm_base);
        },
        5 => {
            var wl_output = prot.new_wl_output(new_id, context, 0);
            wl_output.version = version;
            context.client.wl_output_id = wl_output.id;

            try prot.wl_output_send_geometry(wl_output, 0, 0, 267, 200, @enumToInt(prot.wl_output_subpixel.none), "unknown", "unknown", @enumToInt(prot.wl_output_transform.normal));
            try prot.wl_output_send_mode(wl_output, @enumToInt(prot.wl_output_mode.current), 640, 480, 60000);
            try prot.wl_output_send_scale(wl_output, 1);
            try prot.wl_output_send_done(wl_output);

            try context.register(wl_output);
        },
        6 => {},
        7 => {},
        8 => {
            var wl_shm = prot.new_wl_shm(new_id, context, 0);
            wl_shm.version = version;
            context.client.wl_shm_id = wl_shm.id;

            try prot.wl_shm_send_format(wl_shm, @enumToInt(prot.wl_shm_format.argb8888));
            try prot.wl_shm_send_format(wl_shm, @enumToInt(prot.wl_shm_format.xrgb8888));

            try context.register(wl_shm);
        },
        9 => {},
        10 => {},
        else => {},
    }
}
