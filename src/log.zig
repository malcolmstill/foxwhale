const std = @import("std");

pub fn success(comptime fmt: []const u8, args: var) void {
    var tty = std.debug.detectTTYConfig();
    var stdout = std.io.getStdOut().outStream();
    tty.setColor(stdout, std.debug.TTY.Color.Bold);
    tty.setColor(stdout, std.debug.TTY.Color.Green);
    std.debug.warn(fmt, args);
    tty.setColor(stdout, std.debug.TTY.Color.Reset);
}

pub fn warn(comptime fmt: []const u8, args: var) void {
    var tty = std.debug.detectTTYConfig();
    var stdout = std.io.getStdOut().outStream();
    tty.setColor(stdout, std.debug.TTY.Color.Dim);
    tty.setColor(stdout, std.debug.TTY.Color.Red);
    std.debug.warn(fmt, args);
    tty.setColor(stdout, std.debug.TTY.Color.Reset);
}

pub fn err(comptime fmt: []const u8, args: var) void {
    var tty = std.debug.detectTTYConfig();
    var stdout = std.io.getStdOut().outStream();
    tty.setColor(stdout, std.debug.TTY.Color.Bold);
    tty.setColor(stdout, std.debug.TTY.Color.Red);
    std.debug.warn(fmt, args);
    tty.setColor(stdout, std.debug.TTY.Color.Reset);
}