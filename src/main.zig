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

const log = std.log.scoped(.foxwhale);

pub fn main() !void {
    std.debug.print("Starting gunflint...\n", .{});

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var epoll = try Epoll(Subsystem, SubsystemIterator, Event, Target).init(allocator);
    defer epoll.deinit();

    var server = try Server.init(allocator);
    defer server.deinit();

    try epoll.addFd(server.server.stream.handle, Target{ .server = &server });

    var backend = try Backend.init(allocator, .x11);
    defer backend.deinit();

    try epoll.addFd(backend.getFd(), Target{ .backend = &backend });

    {
        var output = try backend.newOutput(800, 600);
        _ = try server.addOutput(&output);
    }

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();
    try renderer.initShaders();

    // Render all outputs initially
    {
        var it = server.outputs.iterator();
        while (it.next()) |output| {
            try renderer.render();
            try output.backend_output.swap();
        }
    }

    var counter = FrameCounter.init();

    while (server.running) {
        var it = epoll.wait(-1);

        while (try it.next()) |s| switch (s) {
            // 1. Handle new wayland connections
            .server => |ev| switch (ev.event) {
                .client_connected => |conn| {
                    log.info("client {} connected", .{conn.stream.handle});
                    const client = try server.addClient(conn);
                    try epoll.addFd(conn.stream.handle, Target{ .client = client });
                },
            },
            // 2. Handle wayland events per client
            .client => |ev| switch (ev.event) {
                .hangup => {
                    log.info("client {} disconnected", .{ev.client.conn.stream.handle});
                    try epoll.removeFd(ev.client.conn.stream.handle);
                    server.removeClient(ev.client);
                },
                .message => |m| try ev.client.dispatch(m),
                .err => std.debug.print("got err\n", .{}),
            },
            .backend => |ev| switch (ev.event) {
                .key_press => |kp| {
                    // log.info("button press = {} {} (0x{x})", .{ bp.button, bp.state, ev.output });

                    try server.keyboard(kp.time, kp.button, kp.state);
                },
                .button_press => |bp| {
                    // log.info("button press = {} {} (0x{x})", .{ bp.button, bp.state, ev.output });

                    try server.mouseClick(bp.button, bp.state);
                },
                .mouse_move => |e| {
                    // log.info("mouse move = {d}x{d} (0x{x})", .{ e.dx, e.dy, ev.output });

                    try server.mouseMove(e.dx, e.dy);
                },
                .resize => |e| {
                    log.info("resize = {}x{} (0x{x})", .{ e.width, e.height, ev.output });

                    // 1. Get compositor output from event
                    // 2. Update output's view with new size
                    var oit = server.outputs.iterator();
                    while (oit.next()) |_| {
                        //
                    }
                },
                .sync => |_| {
                    // TODO: For the moment, let's draw all outputs on every sync.
                    // Later on we'll figure out how to only sync the output
                    // specified in the event.

                    // TODO: For the moment we will draw but we'll want to trigger a
                    // timer instead, the idea being that we continue to allow
                    // events such that we are not always "1 frame late".
                    counter.update(&server);

                    try renderer.render();

                    var oit = server.outputs.iterator();
                    while (oit.next()) |output| {
                        for (output.views) |view| {
                            if (!view.visible()) continue;

                            var vit = view.back();
                            while (vit) |window| : (vit = window.toplevel.next) {
                                // log.info("drawing {}", .{window.wl_surface.id});
                                try window.render(output.getWidth(), output.getHeight(), &renderer, 0, 0);
                            }
                        }

                        try output.backend_output.swap();
                    }

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
        _ = server;
        self.frames += 1;
        const now = std.time.milliTimestamp();

        if ((now - self.then) > 5000) {
            // std.log.info("fps = {}", .{self.frames / 5});
            // server.usage();
            self.then = now;
            self.frames = 0;
        }
    }
};
