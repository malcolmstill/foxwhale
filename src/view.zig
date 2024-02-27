const std = @import("std");
const prot = @import("wl/protocols.zig");
const Focus = @import("focus.zig").Focus;
const Window = @import("resource/window.zig").Window;

const log = std.log.scoped(.view);

pub const View = struct {
    top: ?*Window = null,
    pointer_window: ?*Window = null,
    active_window: ?*Window = null,
    focus: Focus = .Click,
    width: i32,
    height: i32,

    const Self = @This();

    pub fn init(width: i32, height: i32) View {
        return .{
            .width = width,
            .height = height,
        };
    }

    pub fn visible(_: *const Self) bool {
        return true;
    }

    pub fn back(view: *const Self) ?*Window {
        var it = view.top;
        var window: ?*Window = null;
        while (it) |w| : (it = w.toplevel.prev) {
            window = w;
        }

        return window;
    }

    pub fn push(view: *Self, window: *Window) void {
        const old_top = view.top;

        defer std.debug.assert(view.top == window);
        defer std.debug.assert(window.toplevel.prev == old_top);
        defer std.debug.assert(old_top == null or old_top.?.toplevel.next == window);

        log.info("push (client@{} wl_surface@{})", .{ window.client.conn.stream.handle, window.wl_surface.id });
        if (old_top) |top| {
            if (top == window) return;

            top.toplevel.next = window;
            window.toplevel.prev = top;
        }

        view.top = window;
    }

    pub fn remove(view: *Self, window: *Window) void {
        log.info("remove (client@{} wl_surface@{})", .{ window.client.conn.stream.handle, window.wl_surface.id });
        if (view.top == window) {
            log.info("window was toplevel", .{});
            view.top = window.toplevel.prev;
        }

        window.toplevel.deinit();
    }

    pub fn mouseClick(view: *View, button: u32, action: u32) !void {
        if (view.pointer_window) |pointer_window| {
            if (action == 1) {
                // Raise the window under the pointer if not already
                // at the top.
                if (view.top != pointer_window.toplevelWindow()) {
                    view.raise(pointer_window.toplevelWindow());
                }

                // Activate the clicked window if not already active (deactivate
                // the old active window if necessary).
                if (pointer_window.toplevelWindow() != view.active_window) {
                    if (view.active_window) |active_window| {
                        try active_window.deactivate();
                    }

                    try pointer_window.activate();
                    view.active_window = pointer_window;
                }
            }

            try pointer_window.mouseClick(button, action);
        } else {
            if (view.active_window) |active_window| {
                if (action == 1) {
                    try active_window.deactivate();
                    view.active_window = null;
                }
            }
        }
    }

    fn raise(view: *Self, raising_window: *Window) void {
        log.info("raise (client@{} wl_surface@{})", .{ raising_window.client.conn.stream.handle, raising_window.wl_surface.id });

        // 1. iterate down, removing any marks
        var it = view.top;
        while (it) |window| : (it = window.toplevel.prev) {
            window.toplevel.mark = false;
        }

        // 2. Raise our parent if it exists
        if (raising_window.parent) |parent| {
            // var root = pointer_window.root();
            const parent_toplevel = parent.toplevelWindow();
            parent.toplevel.mark = true;
            view.remove(parent_toplevel);
            view.push(parent_toplevel);
        }

        // 3. Raise our window
        var raising_window_toplevel = raising_window.toplevelWindow();
        view.remove(raising_window_toplevel);
        view.push(raising_window_toplevel);
        raising_window_toplevel.toplevel.mark = true;

        // 4. Raise any of our children
        it = view.back();
        while (it) |window| : (it = window.toplevel.next) {
            if (window.toplevel.mark == true) break;
            if (window.parent != raising_window.toplevelWindow()) continue;

            view.remove(window);
            view.push(window);
            window.toplevel.mark = true;
        }
    }

    pub fn updatePointer(view: *View, x: f64, y: f64) !void {
        const old_pointer_window = view.pointer_window;

        // Iterate from front to back to find the window under the
        // pointer (if any)
        view.pointer_window = null;
        var it = view.top;
        while (it) |window| : (it = window.toplevel.prev) {
            view.pointer_window = window.windowUnderPointer(x, y) orelse continue;
            break;
        }

        // If the pointer window has changed
        // 1. Send pointer leave and deactivate to old pointer window
        //    (where not null).
        // 2. Where the new pointer window is not null, send pointer
        //    enter and activate if focus follows mouse.
        if (old_pointer_window != view.pointer_window) {
            if (old_pointer_window) |old| {
                try old.pointerLeave();
                if (view.focus == Focus.FollowsMouse) {
                    try old.deactivate();
                    view.active_window = null;
                }
            }

            if (view.pointer_window) |window| {
                try window.pointerEnter(x, y);
                if (view.focus == Focus.FollowsMouse) {
                    try window.activate();
                    view.active_window = window;
                }
            } else {
                // log.warn("new pointer_window: null", .{});
                // FIXME: reinstate
                // compositor.COMPOSITOR.client_cursor = null;
            }
        }

        if (view.pointer_window) |window| {
            try window.pointerMotion(x, y);
        }
    }

    pub fn keyboard(view: *Self, time: u32, button: u32, action: u32) !void {
        const active_window = view.active_window orelse return;

        try active_window.keyboardKey(time, button, action);
    }

    pub fn mouseAxis(view: *Self, time: u32, axis: u32, value: f64) !void {
        const pointer_window = view.pointer_window orelse return;

        try pointer_window.mouseAxis(time, axis, value);
    }
};
