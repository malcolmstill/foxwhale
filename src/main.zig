const std = @import("std");
const Context = @import("wl/context.zig").Context;
const Display = @import("display.zig").Display;
const epoll = @import("epoll.zig");
const Backend = @import("backend/backend.zig").Backend;
const BackendType = @import("backend/backend.zig").BackendType;
const bknd = @import("backend/backend.zig");
const render = @import("renderer.zig");
const out = @import("output.zig");
const Output = @import("output.zig").Output;

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = bknd.detect();
    var backend: Backend = try bknd.init(detected_type);
    defer backend.deinit();

    var o1: *Output = try out.newOutput(&backend, 640, 480);
    var o2: *Output = try out.newOutput(&backend, 300, 300);
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

        var it = out.OUTPUTS.iterator();
        while (it.next()) |next_output| {
            next_output.begin();
            try render.render(next_output);
            next_output.swap();
        }

        // if (output.shouldClose()) {
            // running = false;
        // }
    }
}
