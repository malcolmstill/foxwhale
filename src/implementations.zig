const std = @import("std");
const prot = @import("wl/protocols.zig");
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;

const wl_compositor_impl = @import("wl_compositor.zig");
const wl_display_impl = @import("wl_display.zig");
const wl_registry_impl = @import("wl_registry.zig");
const wl_region_impl = @import("wl_region.zig");
const wl_seat_impl = @import("wl_seat.zig");
const wl_shm_pool_impl = @import("wl_shm_pool.zig");
const wl_shm_buffer_impl = @import("wl_shm_buffer.zig");
const wl_surface_impl = @import("wl_surface.zig");
const xdg_base_impl = @import("xdg_base.zig");
const xdg_surface_impl = @import("xdg_surface.zig");
const xdg_toplevel_impl = @import("xdg_toplevel.zig");

pub fn init() void {
    wl_compositor_impl.init();
    wl_display_impl.init();
    wl_region_impl.init();
    wl_registry_impl.init();
    wl_seat_impl.init();
    wl_shm_pool_impl.init();
    wl_shm_buffer_impl.init();
    wl_surface_impl.init();

    xdg_base_impl.init();
    xdg_surface_impl.init();
    xdg_toplevel_impl.init();
}
