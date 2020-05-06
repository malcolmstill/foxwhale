const std = @import("std");
const wl = @import("wl/protocols.zig");
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const Object = @import("wl/context.zig").Object;
const win = @import("window.zig");

pub fn init() void {    
    wl.WL_COMPOSITOR.create_surface = create_surface;
}

fn create_surface(context: *Context, compositor: Object, new_id: u32) anyerror!void {
    std.debug.warn("create_surface: {}\n", .{new_id});

    var window = try win.newWindow(context.client, new_id);

    var surface = wl.new_wl_surface(new_id, context, @ptrToInt(window));
    try context.register(surface);
}
