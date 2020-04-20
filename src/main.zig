const std = @import("std");
const ctx = @import("object.zig");

pub fn main() anyerror!void {
    std.debug.warn("All your codebase are belong to us.\n", .{});

    var c = ctx.Context();

    try c.fds.writeItem(12);
    try c.fds.writeItem(13);
    try c.fds.writeItem(14);
    try c.fds.writeItem(12);

    std.debug.warn("All your codebase are belong to us. {}\n", .{ c.fds.readItem() });
}
