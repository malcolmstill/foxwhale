const std = @import("std");
const Context = @import("client.zig").Context;
const Display = @import("display.zig").Display;
const epoll = @import("epoll.zig");
const Backend = @import("backend/backend.zig").Backend;
const bknd = @import("backend/backend.zig");
const render = @import("renderer.zig");
const out = @import("output.zig");
const Output = @import("output.zig").Output;
const views = @import("view.zig");

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = bknd.detect();
    var backend: Backend = try bknd.init(detected_type);
    defer backend.deinit();

    var o1: *Output = try out.newOutput(&backend, 640, 480);
    // var o2: *Output = try out.newOutput(&backend, 300, 300);

    views.CURRENT_VIEW = &o1.views[0];

    std.debug.warn("==> backend: {}\n", .{backend.name()});

    var display = try Display.init();
    defer { display.deinit(); }
    try display.addToEpoll();

    try render.init();

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

                if (view.iterator()) |*win_it| {
                    while(win_it.next()) |window| {
                        try window.render();
                    }
                }
            }

            output.swap();
            output.end();

            if (output.shouldClose()) {
                try output.deinit();
            }
        }
    }
}
