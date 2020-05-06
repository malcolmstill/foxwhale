const std = @import("std");
const wl = @import("wl/protocols.zig");
const Object = @import("wl/context.zig").Object;
const Client = @import("client.zig").Client;
const Window = @import("window.zig").Window;

pub fn init() void {    
    wl.WL_SURFACE.commit = commit;
    wl.WL_SURFACE.damage = damage;
    wl.WL_SURFACE.attach = attach;
    wl.WL_SURFACE.frame = frame;
}

fn commit(surface: Object) anyerror!void {
    var window = @intToPtr(*Window, surface.container);
    var display_id = window.client.display orelse return error.NoDisplayId;
    var display = surface.context.get(display_id) orelse return error.NoDisplay;

    if (window.wl_buffer) |buffer_id| {
        if (surface.context.get(buffer_id)) |buffer| {
            try wl.wl_buffer_send_release(buffer.*);
        }
    }

    while(window.callbacks.readItem()) |callback_id| {
        if (surface.context.get(callback_id)) |callback| {
            try wl.wl_callback_send_done(callback.*, 1000);
            try surface.context.unregister(callback.*);
            try wl.wl_display_send_delete_id(display.*, callback_id);
        } else {
            return error.CallbackIdNotFound;
        }
    } else |err| {}
}

fn damage(surface: Object, x: i32, y: i32, width: i32, height: i32) anyerror!void {
    std.debug.warn("damage does nothing\n", .{});
}

fn attach(surface: Object, buffer: Object, x: i32, y: i32) anyerror!void {
    var window = @intToPtr(*Window, surface.container);
    // window.pending = true;
    window.wl_buffer = buffer.id;
}

fn frame(surface: Object, new_callback_id: u32) anyerror!void {
    var container = surface.container;
    // Note: we explicitly save surface.container in this variable.
    //
    // I've just spent some hours figuring out a SIGSEGV / incorrect alignment
    // issue because:
    // a) the incoming Object is, under the hood, a pointer to the Object
    //    in the Object hashmap
    // b) the call to new_wl_callback can potentially cause a reallocation of
    //    Objects in said hashmap. This will invalidate the data inside surface.
    //
    // Ideally, we'd want the incoming Object structs to be copies.

    if (wl.new_wl_callback(surface.context, new_callback_id)) |callback| {
        var window = @alignCast(@alignOf(Window), @intToPtr(*Window, container));
        try window.callbacks.writeItem(new_callback_id);
    }
}