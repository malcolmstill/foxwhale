const std = @import("std");
const prot = @import("protocols.zig");
const Context = @import("client.zig").Context;
const Object = @import("client.zig").Object;

const fw_control_impl = @import("implementations/fw_control.zig");
const wl_compositor_impl = @import("implementations/wl_compositor.zig");
const wl_data_device_manager_impl = @import("implementations/wl_data_device_manager.zig");
const wl_display_impl = @import("implementations/wl_display.zig");
const wl_pointer_impl = @import("implementations/wl_pointer.zig");
const wl_registry_impl = @import("implementations/wl_registry.zig");
const wl_region_impl = @import("implementations/wl_region.zig");
const wl_seat_impl = @import("implementations/wl_seat.zig");
const wl_shm_pool_impl = @import("implementations/wl_shm_pool.zig");
const wl_shm_buffer_impl = @import("implementations/wl_shm_buffer.zig");
const wl_subcompositor_impl = @import("implementations/wl_subcompositor.zig");
const wl_subsurface_impl = @import("implementations/wl_subsurface.zig");
const wl_surface_impl = @import("implementations/wl_surface.zig");
const xdg_base_impl = @import("implementations/xdg_base.zig");
const xdg_popup_impl = @import("implementations/xdg_popup.zig");
const xdg_positioner_impl = @import("implementations/xdg_positioner.zig");
const xdg_surface_impl = @import("implementations/xdg_surface.zig");
const xdg_toplevel_impl = @import("implementations/xdg_toplevel.zig");
const zwp_linux_buffer_params_impl = @import("implementations/zwp_linux_buffer_params.zig");
const zwp_linux_dmabuf_impl = @import("implementations/zwp_linux_dmabuf.zig");

pub fn init() void {
    fw_control_impl.init();

    wl_compositor_impl.init();
    wl_data_device_manager_impl.init();
    wl_display_impl.init();
    wl_pointer_impl.init();
    wl_region_impl.init();
    wl_registry_impl.init();
    wl_seat_impl.init();
    wl_shm_pool_impl.init();
    wl_shm_buffer_impl.init();
    wl_subcompositor_impl.init();
    wl_subsurface_impl.init();
    wl_surface_impl.init();

    xdg_base_impl.init();
    xdg_popup_impl.init();
    xdg_positioner_impl.init();
    xdg_surface_impl.init();
    xdg_toplevel_impl.init();

    zwp_linux_buffer_params_impl.init();
    zwp_linux_dmabuf_impl.init();
}
