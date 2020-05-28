const std = @import("std");
const Context = @import("client.zig").Context;
const Display = @import("display.zig").Display;
const Cursor = @import("cursor.zig").Cursor;
const epoll = @import("epoll.zig");
const Backend = @import("backend/backend.zig").Backend;
const bknd = @import("backend/backend.zig");
const render = @import("renderer.zig");
const out = @import("output.zig");
const Output = @import("output.zig").Output;
const views = @import("view.zig");
const windows = @import("window.zig");
const compositor = @import("compositor.zig");

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = bknd.detect();
    var backend: Backend = try bknd.init(detected_type);
    defer backend.deinit();

    try compositor.COMPOSITOR.init();

    var o1: *Output = try out.newOutput(&backend, 640, 480);
    var o2: *Output = try out.newOutput(&backend, 300, 300);

    views.CURRENT_VIEW = &o1.views[0];

    std.debug.warn("==> backend: {}\n", .{backend.name()});

    var display = try Display.init();
    defer { display.deinit(); }
    try display.addToEpoll();

    try render.init();

    var cursor = try Cursor.init();

    var running = true;
    while (running) {
        var i: usize = 0;
        var n = epoll.wait(backend.wait());

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }

        var out_it = out.OUTPUTS.iterator();
        while (out_it.next()) |output| {
            try output.begin();
            try render.render(output);

            for (output.views) |*view| {
                if (view.visible() == false) {
                    continue;
                }

                var it = view.back();
                while(it) |window| : (it = window.toplevel.next) {
                    try window.render();
                }
            }

            if (views.CURRENT_VIEW.output == output) {
                try cursor.render(
                    @floatToInt(i32, compositor.COMPOSITOR.pointer_x),
                    @floatToInt(i32, compositor.COMPOSITOR.pointer_y),
                );
            }

            output.swap();
            output.end();

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
