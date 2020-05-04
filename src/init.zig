const std = @import("std");
const wl = @import("wl/wayland.zig");

pub fn init() void {
    wl.WL_DISPLAY.sync = sync;
    wl.WL_DISPLAY.get_registry = get_registry;
}

fn sync(new_id: u32) void {
    std.debug.warn("sync with id {}\n", .{new_id});
}

fn get_registry(new_id: u32) void {
    std.debug.warn("get_registry with id {}\n", .{new_id});
}