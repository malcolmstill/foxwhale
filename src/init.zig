const std = @import("std");
const wl = @import("wl/protocols.zig");
const Object = @import("wl/context.zig").Object;
const win = @import("window.zig");
const Window = @import("window.zig").Window;

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
    wl.WL_REGISTRY.bind = bind;
    wl.WL_COMPOSITOR.create_surface = create_surface;
    wl.XDG_WM_BASE.get_xdg_surface = get_xdg_surface;
    wl.XDG_SURFACE.get_toplevel = get_toplevel;
    wl.XDG_TOPLEVEL.set_title = set_title;
}

fn sync(object: Object, new_id: u32) void {
    std.debug.warn("sync with id {}\n", .{new_id});
    if(wl.new_wl_callback(object.context, new_id)) |callback| {
        wl.wl_callback_send_done(callback.*, 0);
        var x = object.context.unregister(callback.*);
        wl.wl_display_send_delete_id(object, callback.id);
    }
}

fn get_registry(object: Object, new_id: u32) void {
    std.debug.warn("get_registry with id {}\n", .{new_id});
    if (wl.new_wl_registry(object.context, new_id)) |registry| {
        wl.wl_registry_send_global(registry.*, 1, "wl_compositor\x00", 4);
        wl.wl_registry_send_global(registry.*, 2, "wl_subcompositor\x00", 1);
        wl.wl_registry_send_global(registry.*, 3, "wl_seat\x00", 4);
        wl.wl_registry_send_global(registry.*, 4, "xdg_wm_base\x00", 1);
        wl.wl_registry_send_global(registry.*, 5, "wl_output\x00", 2);
        wl.wl_registry_send_global(registry.*, 6, "wl_data_device_manager\x00", 3);
        wl.wl_registry_send_global(registry.*, 7, "wl_shell\x00", 1);
        wl.wl_registry_send_global(registry.*, 8, "wl_shm\x00", 1);
        wl.wl_registry_send_global(registry.*, 9, "zxdg_decoration_manager_v1\x00", 1);
        wl.wl_registry_send_global(registry.*, 10, "zwp_linux_dmabuf_v1\x00", 3);
    }
}

fn bind(registry: Object, name: u32, name_string: []u8, version: u32, new_id: u32) void {
    std.debug.warn("bind for {} ({}) with id {} at version {}\n", .{name_string, name, new_id, version});

    switch (name) {
        1 => {
            if(wl.new_wl_compositor(registry.context, new_id)) |compositor| {
                compositor.version = version;
                registry.context.client.compositor = compositor.id;
            }
        },
        2 => {
            if(wl.new_wl_subcompositor(registry.context, new_id)) |subcompositor| {
                subcompositor.version = version;
                registry.context.client.subcompositor = subcompositor.id;
            }
        },
        3 => {
            if (registry.context.client.seat == null) {
                if (wl.new_wl_seat(registry.context, new_id)) |seat| {
                    seat.version = version;
                    wl.wl_seat_send_capabilities(seat.*, @enumToInt(wl.wl_seat_capability.pointer) | @enumToInt(wl.wl_seat_capability.keyboard));
                    registry.context.client.seat = seat.id;
                }
            }
        },
        4 => {
            if (wl.new_xdg_wm_base(registry.context, new_id)) |base| {
                base.version = version;
                registry.context.client.xdg_wm_base = base.id;
            }
        },
        5 => {},
        6 => {},
        7 => {},
        8 => {
            if(wl.new_wl_shm(registry.context, new_id)) |shm| {
                shm.version = version;
                registry.context.client.shm = shm.id;

                wl.wl_shm_send_format(shm.*, @enumToInt(wl.wl_shm_format.argb8888));
                wl.wl_shm_send_format(shm.*, @enumToInt(wl.wl_shm_format.xrgb8888));
            }
        },
        9 => {},
        10 => {},
        else => {},
    }
}

fn create_surface(compositor: Object, id: u32) void {
    std.debug.warn("create_surface: {}\n", .{id});
    if (wl.new_wl_surface(compositor.context, id)) |surface| {
        var x = win.newWindow(compositor.context.client, id);
    }
}

fn get_xdg_surface(base: Object, id: u32, surface: Object) void {
    std.debug.warn("get_xdg_surface: {}\n", .{id});
    if (wl.new_xdg_surface(base.context, id)) |xdg_surface| {
        var window = @intToPtr(*Window, surface.container);
        window.xdg_surface = xdg_surface.id;
        xdg_surface.container = @ptrToInt(window);
    }
}

fn get_toplevel(xdg_surface: Object, id: u32) void {
    std.debug.warn("get_toplevel: {}\n", .{id});
    if (wl.new_xdg_toplevel(xdg_surface.context, id)) |xdg_toplevel| {
        var window = @intToPtr(*Window, xdg_surface.container);
        window.xdg_toplevel = xdg_toplevel.id;
        xdg_toplevel.container = @ptrToInt(window);
    }
}

fn set_title(xdg_toplevel: Object, title: []u8) void {
    var window = @intToPtr(*Window, xdg_toplevel.container);
    var len = std.math.min(window.title.len, title.len);
    std.mem.copy(u8, window.title[0..len], title[0..len]);
    std.debug.warn("window: {}\n", .{window.title});
}