const std = @import("std");
const Context = @import("wl/context.zig").Context;
const Display = @import("display.zig").Display;
const epoll = @import("epoll.zig");
const init = @import("init.zig");
const Backend = @import("backend/backend.zig").Backend;
const BackendType = @import("backend/backend.zig").BackendType;
const bknd = @import("backend/backend.zig");

pub fn main() anyerror!void {
    try epoll.init();
    var detected_type = bknd.detect();
    var backend: Backend = try bknd.init(detected_type);
    defer backend.deinit();

    std.debug.warn("backend: {} (size: {})\n", .{backend, @sizeOf(Backend)});

    var display = try Display.init();
    defer { display.deinit(); }
    try display.addToEpoll();

    init.init();

    var running = true;
    while (running) {
        var i: usize = 0;
        var n = epoll.wait(backend.wait());

        while (i < n) {
            try epoll.dispatch(i);
            i = i + 1;
        }

        backend.draw();

        if (backend.shouldClose()) {
            running = false;
        }
    }
}
