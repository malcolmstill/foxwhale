const std = @import("std");
const Server = @import("server.zig").Server;
const Epoll = @import("epoll.zig").Epoll;
const Subsystem = @import("subsystem.zig").Subsystem;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Event = @import("subsystem.zig").Event;
const Target = @import("subsystem.zig").Target;
const Backend = @import("backend/backend.zig").Backend;
const Renderer = @import("renderer.zig").Renderer;
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

    _ = try server.addOutput(&output);

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();
    try renderer.initShaders();

    try output.swap();

    var counter = FrameCounter.init();

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
                    std.log.info("hangup removing client", .{});
                    try epoll.removeFd(ev.client.conn.stream.handle);
                    server.removeClient(ev.client);
                },
                .message => |m| try ev.client.dispatch(m),
                .err => std.debug.print("got err\n", .{}),
            },
            .backend => |ev| switch (ev.event) {
                .button_press => |bp| std.log.info("button press = {}", .{bp}),
                .resize => |e| std.log.info("resize = {}x{}", .{ e.width, e.height }),
                .sync => {
                    // For the moment we will draw but we'll want to trigger a timer instead
                    counter.update(&server);
                    try renderer.render();

                    {
                        var win_it = server.windows.iterator();

                        while (win_it.next()) |window| {
                            try window.render(output.getWidth(), output.getHeight(), &renderer, 0, 0);
                        }
                    }

                    try output.swap();

                    {
                        var win_it = server.windows.iterator();

                        while (win_it.next()) |window| {
                            try window.frameCallback();
                        }
                    }
                },
            },
        };
    }
}

const FrameCounter = struct {
    frames: usize = 0,
    then: i64,

    pub fn init() FrameCounter {
        return FrameCounter{
            .then = std.time.milliTimestamp(),
        };
    }

    pub fn update(self: *FrameCounter, server: *Server) void {
        self.frames += 1;
        const now = std.time.milliTimestamp();

        if ((now - self.then) > 5000) {
            std.log.info("fps = {}", .{self.frames / 5});
            server.usage();
            self.then = now;
            self.frames = 0;
        }
    }
};
