const std = @import("std");
const wl = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const win = @import("window.zig");
const Window = @import("window.zig").Window;
const surface_impl = @import("surface.zig");
const shm_pool_impl = @import("shm_pool.zig");
const shm_buffer_impl = @import("shm_buffer.zig");

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
    wl.WL_REGISTRY.bind = bind;
    wl.WL_COMPOSITOR.create_surface = create_surface;
    wl.XDG_WM_BASE.get_xdg_surface = get_xdg_surface;
    wl.XDG_SURFACE.get_toplevel = get_toplevel;
    wl.XDG_SURFACE.ack_configure = ack_configure;
    wl.XDG_TOPLEVEL.set_title = set_title;

    surface_impl.init();
    shm_pool_impl.init();
    shm_buffer_impl.init();
}

fn sync(context: *Context, display: Object, new_id: u32) anyerror!void {
    std.debug.warn("sync with id {}\n", .{new_id});

    var callback = wl.new_wl_callback(new_id, display.context, 0);
    try wl.wl_callback_send_done(callback, 120);
    try wl.wl_display_send_delete_id(display, callback.id);
}

fn get_registry(context: *Context, display: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_registry with id {} {}\n", .{new_id, display});

    var registry = wl.new_wl_registry(new_id, context, 0);
    std.debug.warn("wl_registry: {}\n", .{registry});

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
            var compositor = wl.new_wl_compositor(new_id, context, 0);
            compositor.version = version;
            context.client.compositor = compositor.id;

            try context.register(compositor);
        },
        2 => {
            var subcompositor = wl.new_wl_subcompositor(new_id, context, 0);
            subcompositor.version = version;
            context.client.subcompositor = subcompositor.id;

            try context.register(subcompositor);
        },
        3 => {
            if (context.client.seat != null) {
                return;
            }

            var seat = wl.new_wl_seat(new_id, context, 0);
            seat.version = version;
            try wl.wl_seat_send_capabilities(seat, @enumToInt(wl.wl_seat_capability.pointer) | @enumToInt(wl.wl_seat_capability.keyboard));
            context.client.seat = seat.id;

            try context.register(seat);
        },
        4 => {
            var base = wl.new_xdg_wm_base(new_id, context, 0);
            base.version = version;
            context.client.xdg_wm_base = base.id;

            try context.register(base);
        },
        5 => {},
        6 => {},
        7 => {},
        8 => {
            var shm = wl.new_wl_shm(new_id, context, 0);
            shm.version = version;
            context.client.shm = shm.id;

            try wl.wl_shm_send_format(shm, @enumToInt(wl.wl_shm_format.argb8888));
            try wl.wl_shm_send_format(shm, @enumToInt(wl.wl_shm_format.xrgb8888));

            try context.register(shm);
        },
        9 => {},
        10 => {},
        else => {},
    }
}

fn create_surface(context: *Context, compositor: Object, new_id: u32) anyerror!void {
    std.debug.warn("create_surface: {}\n", .{new_id});

    var window = try win.newWindow(context.client, new_id);

    var surface = wl.new_wl_surface(new_id, context, @ptrToInt(window));
    try context.register(surface);
}

fn get_xdg_surface(context: *Context, base: Object, new_id: u32, surface: Object) anyerror!void {
    std.debug.warn("get_xdg_surface: {}\n", .{new_id});

    var window = @intToPtr(*Window, surface.container);
    window.xdg_surface = new_id;

    var xdg_surface = wl.new_xdg_surface(new_id, context, @ptrToInt(window));
    try context.register(xdg_surface);
}

fn get_toplevel(context: *Context, xdg_surface: Object, new_id: u32) anyerror!void {
    std.debug.warn("get_toplevel: {}\n", .{new_id});

    var window = @intToPtr(*Window, xdg_surface.container);
    window.xdg_toplevel = new_id;

    var xdg_toplevel = wl.new_xdg_toplevel(new_id, context, @ptrToInt(window));

    var array = [_]u32{};
    var serial = window.client.nextSerial();
    try wl.xdg_toplevel_send_configure(xdg_toplevel, 0, 0, array[0..array.len]);
    try wl.xdg_surface_send_configure(xdg_surface, serial);

    try context.register(xdg_toplevel);
}

fn set_title(context: *Context, xdg_toplevel: Object, title: []u8) anyerror!void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}


fn ack_configure(context: *Context, object: Object, serial: u32) anyerror!void {
    std.debug.warn("ack_configure empty implementation\n", .{});
}