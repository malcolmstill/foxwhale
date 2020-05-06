const std = @import("std");
const prot = @import("wl/protocols.zig");
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const win = @import("window.zig");

fn create_surface(context: *Context, wl_compositor: Object, new_id: u32) anyerror!void {
    std.debug.warn("create_surface: {}\n", .{new_id});

    var window = try win.newWindow(context.client, new_id);

    var surface = prot.new_wl_surface(new_id, context, @ptrToInt(window));
    try context.register(surface);
}

pub fn init() void {
    prot.WL_COMPOSITOR.create_surface = create_surface;
}