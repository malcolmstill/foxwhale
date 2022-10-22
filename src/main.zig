const std = @import("std");
const Server = @import("server.zig").Server;
const Epoll = @import("epoll.zig").Epoll;
const Subsystem = @import("subsystem.zig").Subsystem;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Event = @import("subsystem.zig").Event;
const Target = @import("subsystem.zig").Target;
const Backend = @import("backend/backend.zig").Backend;
const c = @cImport({
    @cInclude("GLES3/gl3.h");
});
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    std.debug.print("Starting gunflint...\n", .{});

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var epoll = try Epoll(Subsystem, SubsystemIterator, Event, Target).init(allocator);
    defer epoll.deinit();

    var server = try Server.init(allocator);
    defer server.deinit();

    try epoll.addFd(server.server.sockfd.?, Target{ .server = &server });

    var backend = try Backend.init(.x11);
    try epoll.addFd(backend.getFd(), Target{ .backend = &backend });

    var output = try backend.newOutput(400, 300);

    var frames: usize = 0;
    var then = std.time.milliTimestamp();

    while (true) {
        var it = epoll.wait(-1);

        while (try it.next()) |s| switch (s) {
            // 1. Handle new wayland connections
            .server => |ev| switch (ev.event) {
                .client_connected => |conn| {
                    const client = try server.addClient(conn);
                    try epoll.addFd(conn.stream.handle, Target{ .client = client });
                },
            },
            // 2. Handle wayland events per client
            .client => |ev| switch (ev.event) {
                .hangup => {
                    try epoll.removeFd(ev.client.conn.stream.handle);
                    server.removeClient(ev.client);
                },
                .message => |m| try ev.client.dispatch(m),
                .err => std.debug.print("got err\n", .{}),
            },
            .backend => |ev| switch (ev.event) {
                .button_press => |bp| std.log.info("button press = {}", .{bp}),
                .sync => {
                    // For the moment we will draw but we'll want to trigger a timer instead
                    frames += 1;
                    if ((std.time.milliTimestamp() - then) > 5000) {
                        std.log.info("fps = {}", .{frames / 5});
                        then = std.time.milliTimestamp();
                        frames = 0;
                    }
                    c.glClearColor(1.0, 0.0, 0.3, 1.0);
                    c.glClear(c.GL_COLOR_BUFFER_BIT);
                    try output.swap();
                },
            },
        };
    }
}
