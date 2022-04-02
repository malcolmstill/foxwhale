const std = @import("std");
const prot = @import("../protocols.zig");
const Client = @import("../client.zig").Client;
const Context = @import("../client.zig").Context;
const Object = @import("../client.zig").Object;
const win = @import("../window.zig");
const reg = @import("../region.zig");
const view = @import("../view.zig");

fn create_surface(context: *Context, wl_compositor: Object, new_id: u32) anyerror!void {
    std.debug.warn("create_surface: {}\n", .{new_id});

    const window = try win.newWindow(context.client, new_id);
    window.view = context.client.compositor.current_view;

    const surface = prot.new_wl_surface(new_id, context, @ptrToInt(window));
    try context.register(surface);
}

fn create_region(context: *Context, wl_compositor: Object, new_id: u32) anyerror!void {
    const region = try reg.newRegion(context.client, new_id);

    const wl_region = prot.new_wl_region(new_id, context, @ptrToInt(region));
    try context.register(wl_region);
}

pub fn init() void {
    prot.WL_COMPOSITOR.create_surface = create_surface;
    prot.WL_COMPOSITOR.create_region = create_region;
}
