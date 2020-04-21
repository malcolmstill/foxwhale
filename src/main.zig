const std = @import("std");
const ctx = @import("context.zig");

pub fn main() anyerror!void {
    std.debug.warn("All your codebase are belong to us.\n", .{});

    var c = ctx.Context().init();

    try c.fds.writeItem(12);
    try c.fds.writeItem(13);
    try c.fds.writeItem(14);

    std.debug.warn("All your codebase are belong to us. {}\n", .{ c.fds.readItem() });
    std.debug.warn("All your codebase are belong to us. {}\n", .{ c.fds.readItem() });
    std.debug.warn("All your codebase are belong to us. {}\n", .{ c.fds.readItem() });
}
