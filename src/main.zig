const std = @import("std");
const epoll = @import("epoll.zig");
const backends = @import("backend/backend.zig");
const render = @import("renderer.zig");
const out = @import("output.zig");
const views = @import("view.zig");
const windows = @import("window.zig");
const Compositor = @import("compositor.zig").Compositor;
const Comp = @import("compositor.zig");
const Context = @import("client.zig").Context;
const Server = @import("server.zig").Server;
const Cursor = @import("cursor.zig").Cursor;
const Output = @import("output.zig").Output;
const Backend = @import("backend/backend.zig").Backend;
const Renderer = @import("renderer.zig").Renderer;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = backends.detect();
    var backend: Backend = try Backend.new(detected_type);
    try backend.init();
    defer backend.deinit();

    Comp.COMPOSITOR = Compositor.init(allocator());
    var compositor = &Comp.COMPOSITOR; // FIXME: get rid of this global
    defer compositor.deinit();
    try compositor.initInput();
    try compositor.initServer();
    try compositor.initOutputs(&backend);

    std.debug.warn("==> backend: {s}\n", .{backend.name()});

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();

    try renderer.initShaders();

    var cursor = try Cursor.init();
    defer cursor.deinit();

    var frames: u32 = 0;
    var now = std.time.milliTimestamp();
    var then = now;

    while (compositor.running) {
        var i: usize = 0;
        var n = epoll.wait(backend.wait());

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }

        try compositor.animations.update();

        for (compositor.outputs.items) |output| {
            if (output.backend.isPageFlipScheduled()) continue;

            const output_width = output.backend.getWidth();
            const output_height = output.backend.getHeight();
            try output.backend.begin();

            try renderer.clear();
            try renderer.render(output);
            try renderer.renderBackground(output_width, output_height);

            for (output.views) |*view| {
                if (view.visible() == false) continue;

                var it = view.back();
                while (it) |window| : (it = window.toplevel.next) {
                    try window.render(output_width, output_height, &renderer, 0, 0);
                }
            }

            if (compositor.current_view) |view| {
                if (view.output == output) {
                    try cursor.render(
                        compositor.client_cursor,
                        output_width,
                        output_height,
                        &renderer,
                        @floatToInt(i32, compositor.pointer_x),
                        @floatToInt(i32, compositor.pointer_y),
                    );
                }
            }

            try output.backend.swap();
            frames += 1;
            now = std.time.milliTimestamp();
            output.backend.end();

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

            if (output.backend.shouldClose()) {
                try output.backend.deinit();
            }
        }
    }
}
