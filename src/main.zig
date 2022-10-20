const std = @import("std");
const Server = @import("server.zig").Server;
const Epoll = @import("epoll.zig").Epoll;
const Subsystem = @import("subsystem.zig").Subsystem;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Event = @import("subsystem.zig").Event;
const Target = @import("subsystem.zig").Target;
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
                    try epoll.removeFd(ev.target.conn.stream.handle);
                    server.removeClient(ev.target);
                },
                .message => |m| try ev.target.dispatch(m),
                .err => std.debug.print("got err\n", .{}),
            },
        };
    }
}
