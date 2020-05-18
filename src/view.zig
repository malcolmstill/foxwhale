const std = @import("std");
const prot = @import("protocols.zig");
const Window = @import("window.zig").Window;

pub var CURRENT_VIEW: *View = undefined;

pub const View = struct {
    top: ?*Window,
    pointer_window: ?*Window,

    const Self = @This();

    pub fn visible(self: *Self) bool {
        return true;
    }

    pub fn back(self: *Self) ?*Window {
        var it = self.top;
        var window: ?*Window = null;
        while(it) |w| : (it = w.toplevel.prev) {
            window = w;
        }

        return window;
    }

    pub fn push(self: *Self, window: *Window) void {
        if (self.top) |top| {
            if (top == window) {
                return;
            }
            top.toplevel.next = window;
            window.toplevel.prev = top;
        }

        self.top = window;
        std.debug.warn("pushed\n", .{});
    }

    pub fn remove(self: *Self, window: *Window) void {
        if (self.top == window) {
            self.top = window.toplevel.prev;
        }
        window.toplevel.deinit();
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        if (self.pointer_window) |pointer_window| {
            if (self.top) |top| {
                if (top != pointer_window) {
                    if (action == 1) {
                        std.debug.warn("raise\n", .{});
                        self.remove(pointer_window);
                        self.push(pointer_window);
                    }
                }
            }
            try pointer_window.mouseClick(button, action);
        }
    }

    pub fn updatePointer(self: *Self, x: f64, y: f64) !void {
        var new_pointer_window: ?*Window = null;

        var it = self.top;
        while(it) |window| : (it = window.toplevel.prev) {
            if (window.windowUnderPointer(x, y)) |w| {
                new_pointer_window = w;
                break;
            }
        }

        if (new_pointer_window != self.pointer_window) {
            if (self.pointer_window) |pointer_window| {
                var client = pointer_window.client;
                if (client.wl_pointer_id) |wl_pointer_id| {
                    if (client.context.objects.get(wl_pointer_id)) |wl_pointer| {
                        try prot.wl_pointer_send_leave(wl_pointer.value, client.nextSerial(), pointer_window.wl_surface_id);
                    }
                }
            }

            if (new_pointer_window) |window| {
                std.debug.warn("new pointer_window: {}\n", .{window.index});
                var client = window.client;
                if (client.wl_pointer_id) |wl_pointer_id| {
                    if (client.context.objects.get(wl_pointer_id)) |wl_pointer| {
                        try prot.wl_pointer_send_enter(
                            wl_pointer.value,
                            client.nextSerial(),
                            window.wl_surface_id,
                            @floatCast(f32, x - @intToFloat(f64, window.current().x)),
                            @floatCast(f32, y - @intToFloat(f64, window.current().y))
                            );
                    }
                }
            } else {
                std.debug.warn("new pointer_window: null\n", .{});
            }
        }

        self.pointer_window = new_pointer_window;

        if (self.pointer_window) |window| {
            var client = window.client;
            if (client.wl_pointer_id) |wl_pointer_id| {
                if (client.context.objects.get(wl_pointer_id)) |wl_pointer| {
                    try prot.wl_pointer_send_motion(
                        wl_pointer.value,
                        @truncate(u32, std.time.milliTimestamp()),
                        @floatCast(f32, x - @intToFloat(f64, window.current().x)),
                        @floatCast(f32, y - @intToFloat(f64, window.current().y))
                    );
                }
            }
        }
    }

    pub fn deinit(self: *Self) void {

    }
};

pub fn makeView() View {
    return View{
        .top = null,
        .pointer_window = null,
    };
}