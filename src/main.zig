pub var OUTPUT: *CompositorOutput = undefined;
const Renderer = @import("renderer.zig").Renderer;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = backends.detect();
    var backend: Backend = try Backend.new(detected_type);
    try backend.init();
    defer backend.deinit();

    compositor.COMPOSITOR = compositor.Compositor.init(allocator);
    defer compositor.COMPOSITOR.deinit();
    try compositor.COMPOSITOR.initInput();
    try compositor.COMPOSITOR.initServer();

    var o1 = try out.newOutput(&compositor.COMPOSITOR, &backend, 640, 480);
    defer {
        o1.deinit() catch {};
    }
    try o1.addToEpoll();
    OUTPUT = o1;
    // var o2 = try out.newOutput(&backend, 300, 300);

    views.CURRENT_VIEW = &o1.data.views[0];

    std.debug.warn("==> backend: {s}\n", .{backend.name()});

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();

    try renderer.initShaders();

    var cursor = try Cursor.init();
    defer cursor.deinit();

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

        try compositor.COMPOSITOR.animations.update();

        var out_it = out.OUTPUTS.iterator();
        while (out_it.next()) |output| {
            if (output.isPageFlipScheduled() == false) {
                const output_width = output.getWidth();
                const output_height = output.getHeight();
                try output.begin();

                try renderer.clear();
                try renderer.render(output);
                try renderer.renderBackground(output_width, output_height);

                for (output.data.views) |*view| {
                    if (view.visible() == false) {
                        continue;
                    }

                    var it = view.back();
                    while (it) |window| : (it = window.toplevel.next) {
                        try window.render(output_width, output_height, &renderer, 0, 0);
                    }
                }

                if (views.CURRENT_VIEW.output == output) {
                    try cursor.render(
                        compositor.COMPOSITOR.client_cursor,
                        output_width,
                        output_height,
                        &renderer,
                        @floatToInt(i32, compositor.COMPOSITOR.pointer_x),
                        @floatToInt(i32, compositor.COMPOSITOR.pointer_y),
                    );
                }

                try output.swap();
                frames += 1;
                now = std.time.milliTimestamp();
                output.end();

                if ((now - then) > 5000) {
                    std.debug.warn("fps: {}\n", .{frames / 5});
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
