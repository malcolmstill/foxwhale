const std = @import("std");
const prot = @import("../protocols.zig");
const clients = @import("../client.zig");
const windows = @import("../window.zig");
const regions = @import("../region.zig");
const views = @import("../view.zig");
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const Region = @import("../region.zig").Region;
const Window = @import("../window.zig").Window;

fn get_clients(context: *Context, fw_control: Object) anyerror!void {
    var it = clients.CLIENTS.iterator();
    while(it.next()) |client| {
        try prot.fw_control_send_client(fw_control, @intCast(u32, client.getIndexOf()));
    }
    try prot.fw_control_send_done(fw_control);
}

fn get_windows(context: *Context, fw_control: Object) anyerror!void {
    for (windows.WINDOWS) |*window| {
        if (!window.in_use) continue;

        var surface_type: u32 = 0;

        if (window.wl_subsurface_id) |wl_subsurface_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.wl_subsurface);
        }

        if (window.xdg_toplevel_id) |xdg_toplevel_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.xdg_toplevel);
        }

        if (window.xdg_popup_id) |xdg_popup_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.xdg_popup);
        }

        try prot.fw_control_send_window(
            fw_control,
            @intCast(u32, window.index),
            (if (window.parent) |parent| @intCast(i32, parent.index) else -1),
            window.wl_surface_id,
            surface_type,
            window.current().x,
            window.current().y,
            window.width,
            window.height,
            (if (window.current().siblings.prev) |prev| @intCast(i32, prev.index) else -1),
            (if (window.current().siblings.next) |next| @intCast(i32, next.index) else -1),
            (if (window.current().children.prev) |prev| @intCast(i32, prev.index) else -1),
            (if (window.current().children.next) |next| @intCast(i32, next.index) else -1),
            (if (window.current().input_region) |region| region.wl_region_id else 0),
        );

        if (window.current().input_region) |input_region| {
            var slice = input_region.rectangles.readableSlice(0);
            for(slice) |rect| {
                try prot.fw_control_send_region_rect(
                    fw_control,
                    @intCast(u32, regions.REGIONS.getIndexOf(input_region)),
                    rect.rectangle.x,
                    rect.rectangle.y,
                    rect.rectangle.width,
                    rect.rectangle.height,
                    if (rect.op == .Add) 1 else 0,
                );
            }
        }
    }

    try prot.fw_control_send_done(fw_control);
}

fn get_window_trees(context: *Context, fw_control: Object) anyerror!void {
    var view = views.CURRENT_VIEW;

    var it = view.back();
    while(it) |window| : (it = window.toplevel.next) {
        var surface_type: u32 = 0;

        if (window.wl_subsurface_id) |wl_subsurface_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.wl_subsurface);
        }

        if (window.xdg_toplevel_id) |xdg_toplevel_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.xdg_toplevel);
        }

        if (window.xdg_popup_id) |xdg_popup_id| {
            surface_type = @enumToInt(prot.fw_control_surface_type.xdg_popup);
        }

        try prot.fw_control_send_toplevel_window(
            fw_control,
            @intCast(u32, window.index),
            (if (window.parent) |parent| @intCast(i32, parent.index) else -1),
            window.wl_surface_id,
            surface_type,
            window.current().x,
            window.current().y,
            window.width,
            window.height,
            (if (window.current().input_region) |region| region.wl_region_id else 0),
        );

        try window_tree(fw_control, window);
    }
    try prot.fw_control_send_done(fw_control);
}

fn window_tree(fw_control: Object, window: *Window) anyerror!void {
    var win_it = window.backwardIterator();
    while(win_it.prev()) |subwindow| {
        if (window == subwindow) {
            var subsurface_type: u32 = 0;

            if (subwindow.wl_subsurface_id) |wl_subsurface_id| {
                subsurface_type = @enumToInt(prot.fw_control_surface_type.wl_subsurface);
            }

            if (subwindow.xdg_toplevel_id) |xdg_toplevel_id| {
                subsurface_type = @enumToInt(prot.fw_control_surface_type.xdg_toplevel);
            }

            if (subwindow.xdg_popup_id) |xdg_popup_id| {
                subsurface_type = @enumToInt(prot.fw_control_surface_type.xdg_popup);
            }

            try prot.fw_control_send_window(
                fw_control,
                @intCast(u32, subwindow.index),
                (if (subwindow.parent) |parent| @intCast(i32, parent.index) else -1),
                subwindow.wl_surface_id,
                subsurface_type,
                subwindow.current().x,
                subwindow.current().y,
                subwindow.width,
                subwindow.height,
                (if (subwindow.current().siblings.prev) |prev| @intCast(i32, prev.index) else -1),
                (if (subwindow.current().siblings.next) |next| @intCast(i32, next.index) else -1),
                (if (subwindow.current().children.prev) |prev| @intCast(i32, prev.index) else -1),
                (if (subwindow.current().children.next) |next| @intCast(i32, next.index) else -1),
                (if (subwindow.current().input_region) |region| region.wl_region_id else 0),
            );
        } else {
            try window_tree(fw_control, subwindow);
        }
    }    
}

fn destroy(context: *Context, fw_control: Object) anyerror!void {
    try prot.wl_display_send_delete_id(context.client.wl_display, fw_control.id);
    try context.unregister(fw_control);
}

pub fn init() void {
    prot.FW_CONTROL = prot.fw_control_interface{
        .get_clients = get_clients,
        .get_windows = get_windows,
        .get_window_trees = get_window_trees,
        .destroy = destroy,
    };
}
