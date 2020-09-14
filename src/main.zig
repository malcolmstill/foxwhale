pub var OUTPUT: *CompositorOutput = undefined;

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = backends.detect();
    var backend: Backend = try Backend.new(detected_type);
    try backend.init();
    defer backend.deinit();

    try compositor.COMPOSITOR.init();

    var o1 = try out.newOutput(&backend, 640, 480);
    try o1.addToEpoll();
    OUTPUT = o1;
    // var o2 = try out.newOutput(&backend, 300, 300);

    views.CURRENT_VIEW = &o1.data.views[0];

    std.debug.warn("==> backend: {}\n", .{backend.name()});

    var server = try Server.init();
    defer { server.deinit(); }
    try server.addToEpoll();

    try render.init();

    var cursor = try Cursor.init();
    var frames: u32 = 0;
    var now = std.time.milliTimestamp();
    var then = now;

    while (compositor.COMPOSITOR.running) {
        var i: usize = 0;
        var n = epoll.wait(backend.wait());

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }

        var out_it = out.OUTPUTS.iterator();
        while (out_it.next()) |output| {
            if (output.isPageFlipScheduled() == false) {
                try output.begin();

                try render.clear();
                try render.render(output);

                for (output.data.views) |*view| {
                    if (view.visible() == false) {
                        continue;
                    }

                    var it = view.back();
                    while(it) |window| : (it = window.toplevel.next) {
                        try window.render(0, 0);
                    }
                }

                if (views.CURRENT_VIEW.output == output) {
                    try cursor.render(
                        @floatToInt(i32, compositor.COMPOSITOR.pointer_x),
                        @floatToInt(i32, compositor.COMPOSITOR.pointer_y),
                    );
                }

                try output.swap();
                frames += 1;
                now = std.time.milliTimestamp();
                output.end();

                if ((now - then) > 5000) {
                    std.debug.warn("fps: {}\n", .{frames/5});
                    then = now;
                    frames = 0;
                }

                for (windows.WINDOWS) |*window| {
                    if (window.in_use) {
                        try window.frameCallback();
                    }
                }

                if (output.shouldClose()) {
                    try output.deinit();
                }
            }
        }
    }
}

const std = @import("std");
const epoll = @import("epoll.zig");
const backends = @import("backend/backend.zig");
const render = @import("renderer.zig");
const out = @import("output.zig");
const views = @import("view.zig");
const windows = @import("window.zig");
const compositor = @import("compositor.zig");
const Context = @import("client.zig").Context;
const Server = @import("server.zig").Server;
const Cursor = @import("cursor.zig").Cursor;
const Output = @import("output.zig").Output;
const CompositorOutput = @import("output.zig").CompositorOutput;
const Backend = backends.Backend(Output);
