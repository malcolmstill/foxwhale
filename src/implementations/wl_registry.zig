const std = @import("std");
const prot = @import("../protocols.zig");
const out = @import("../output.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;

fn bind(context: *Context, wl_registry: Object, name: u32, name_string: []u8, version: u32, new_id: u32) anyerror!void {
    std.debug.warn("bind for {} ({}) with id {} at version {}\n", .{name_string, name, new_id, version});

    if (name >= out.OUTPUT_BASE) {
        if(out.OUTPUTS.getAtIndex(name - out.OUTPUT_BASE)) |output| {
            var wl_output = prot.new_wl_output(new_id, context, @ptrToInt(output));
            wl_output.version = version;
            context.client.wl_output_id = wl_output.id;

            try prot.wl_output_send_geometry(wl_output, 0, 0, 267, 200, @enumToInt(prot.wl_output_subpixel.none), "unknown", "unknown", @enumToInt(prot.wl_output_transform.normal));
            try prot.wl_output_send_mode(wl_output, @enumToInt(prot.wl_output_mode.current), output.getWidth(), output.getHeight(), 60000);
            try prot.wl_output_send_scale(wl_output, 1);
            try prot.wl_output_send_done(wl_output);

            try context.register(wl_output);
        } else {
            return error.NoSuchOutputInUseToBind;
        }
    }

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
            var wl_seat = prot.new_wl_seat(new_id, context, 0);
            wl_seat.version = version;
            try prot.wl_seat_send_capabilities(wl_seat, @enumToInt(prot.wl_seat_capability.pointer) | @enumToInt(prot.wl_seat_capability.keyboard));

            if (context.client.wl_seat_id != null) {
                context.client.wl_seat_id = wl_seat.id;
            }

            try context.register(wl_seat);
        },
        4 => {
            var xdg_wm_base = prot.new_xdg_wm_base(new_id, context, 0);
            xdg_wm_base.version = version;
            context.client.xdg_wm_base_id = xdg_wm_base.id;

            try context.register(xdg_wm_base);
        },
        6 => {
            var wl_data_device_manager = prot.new_wl_data_device_manager(new_id, context, 0);
            wl_data_device_manager.version = version;
            context.client.wl_data_device_manager_id = wl_data_device_manager.id;

            try context.register(wl_data_device_manager);
        },
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
        11 => {
            var fw_control = prot.new_fw_control(new_id, context, 0);
            fw_control.version = version;
            context.client.fw_control_id = fw_control.id;

            try context.register(fw_control);
        },
        else => {},
    }
}

pub fn init() void {
    prot.WL_REGISTRY.bind = bind;
}