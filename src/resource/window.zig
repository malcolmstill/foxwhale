const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const Renderer = @import("../renderer.zig").Renderer;
const Client = @import("../client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const Region = @import("region.zig").Region;
const Positioner = @import("positioner.zig").Positioner;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const View = @import("../view.zig").View;
const Mat4x4 = @import("../math.zig").Mat4x4;
const Animatable = @import("../animatable.zig").Animatable;
const AnimatableType = @import("../animatable.zig").AnimatableType;
const RemoveError = @import("../client.zig").RemoveError;
const ease = @import("../ease.zig");

const wl = @import("../client.zig").wl;
const endian = builtin.cpu.arch.endian();

const log = std.log.scoped(.window);

pub const XdgConfigurations = LinearFifo(XdgConfiguration, LinearFifoBufferType{ .Static = 32 });
const Callbacks = LinearFifo(wl.WlCallback, LinearFifoBufferType{ .Static = 32 });

pub const Window = struct {
    client: *Client,

    mapped: bool = false,
    // Should we remove `view`?
    view: ?*View = null,

    parent: ?*Window = null,
    popup: ?*Window = null,

    toplevel: Link = Link{},

    ready_for_callback: bool = false,

    texture: ?u32 = null,
    width: i32 = 0,
    height: i32 = 0,

    // Animatable
    scaleX: f32 = 1.0,
    scaleY: f32 = 1.0,
    originX: f32 = 0.0,
    originY: f32 = 0.0,

    first_configure: bool = false,
    first_buffer: bool = false,

    wl_surface: wl.WlSurface,
    wl_buffer: ?wl.WlBuffer = null,
    xdg_surface: ?wl.XdgSurface = null,
    xdg_toplevel: ?wl.XdgToplevel = null,
    xdg_popup_id: ?u32 = null,
    wl_subsurface: ?wl.WlSubsurface = null,

    positioner: ?*Positioner = null,

    window_geometry: ?Rectangle = null,

    synchronized: bool = false,
    state: [2]BufferedState = [_]BufferedState{ BufferedState{}, BufferedState{} },
    stateIndex: u1 = 0,

    // When not null, Rectangle defines the OLD unmaximised geometry
    maximized: ?Rectangle = null,
    xdg_configurations: XdgConfigurations = XdgConfigurations.init(),

    title: [128]u8 = undefined,
    app_id: [256]u8 = undefined,
    callbacks: Callbacks = Callbacks.init(),

    const Self = @This();

    pub fn init(client: *Client, wl_surface: wl.WlSurface) Window {
        return Window{
            .client = client,
            .wl_surface = wl_surface,
        };
    }

    // flip double-buffered state
    pub fn flip(window: *Window) void {
        // std.log.warn("flipping: {}\n", .{window.index});
        window.stateIndex +%= 1;
        if (window.current().input_region != window.pending().input_region) {
            if (window.pending().input_region) |input_region| {
                // try input_region.deinit();
                window.client.removeRegion(input_region);
            }
        }

        if (window.current().opaque_region != window.pending().opaque_region) {
            if (window.pending().opaque_region) |opaque_region| {
                // try opaque_region.deinit();
                window.client.removeRegion(opaque_region);
            }
        }
        window.pending().* = window.current().*;

        // flip synchronized subwindows above window
        var forward_it = window.subwindowIterator();
        while (forward_it.nextPending()) |subwindow| {
            if (subwindow != window and subwindow.synchronized) {
                subwindow.flip();
            }
        }

        // flip synchronized subwindows below window
        var backward_it = window.subwindowIterator();
        while (backward_it.prevPending()) |subwindow| {
            if (subwindow != window and subwindow.synchronized) {
                subwindow.flip();
            }
        }
    }

    /// Get the buffered state currently displayed
    pub fn current(window: *Window) *BufferedState {
        return &window.state[window.stateIndex];
    }

    // Get the pending buffered state
    pub fn pending(window: *Window) *BufferedState {
        return &window.state[window.stateIndex +% 1];
    }

    pub fn render(window: *Window, output_width: i32, output_height: i32, renderer: *Renderer, x: i32, y: i32) !void {
        var it = window.forwardIterator();

        while (it.next()) |w| {
            w.ready_for_callback = true;
            if (w == window) {
                const texture = w.texture orelse continue; // TODO: maybe we should not render subwindows if parent window not ready
                const program = try renderer.useProgram("window");

                const win_x = w.current().x;
                const win_y = w.current().y;
                const abs_x: f32 = @floatFromInt(w.absoluteX() + x);
                const abs_y: f32 = @floatFromInt(w.absoluteY() + y);

                if (w.parent) |parent| {
                    try Renderer.setUniformMatrix(program, "scale", Mat4x4(f32).scale([_]f32{ parent.scaleX, parent.scaleY, 1.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "translate", Mat4x4(f32).translate([_]f32{ abs_x, abs_y, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "origin", Mat4x4(f32).translate([_]f32{ -parent.originX + @as(f32, @floatFromInt(win_x)), -parent.originY + @as(f32, @floatFromInt(win_y)), 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "originInverse", Mat4x4(f32).translate([_]f32{ parent.originX - @as(f32, @floatFromInt(win_x)), parent.originY - @as(f32, @floatFromInt(win_y)), 0.0, 1.0 }).data);
                    try Renderer.setUniformFloat(program, "opacity", 1.0);
                } else {
                    try Renderer.setUniformMatrix(program, "scale", Mat4x4(f32).scale([_]f32{ window.scaleX, window.scaleY, 1.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "translate", Mat4x4(f32).translate([_]f32{ abs_x, abs_y, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "origin", Mat4x4(f32).translate([_]f32{ -window.originX, -window.originY, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "originInverse", Mat4x4(f32).translate([_]f32{ window.originX, window.originY, 0.0, 1.0 }).data);
                    try Renderer.setUniformFloat(program, "opacity", 1.0);
                }

                try renderer.renderSurface(output_width, output_height, program, texture, w.width, w.height);
            } else {
                try w.render(output_width, output_height, renderer, x, y);
            }
        }

        if (window.popup) |popup| {
            try popup.render(output_width, output_height, renderer, x, y);
        }
    }

    pub fn firstCommit(_: *Window) !void {
        // self.originX = @intToFloat(f32, self.width) / 2.0;
        // self.originY = @intToFloat(f32, self.height) / 2.0;
        // self.scaleX = 0.0;
        // self.scaleY = 6.0 / @intToFloat(f32, self.height);

        // TODO: reinstate
        // const seq = try compositor.COMPOSITOR.animations.addSequential();
        // try seq.addProperty(Animatable.Property{
        //     .initial_value = self.scaleX,
        //     .final_value = 1.0,
        //     .easing = ease.OutExpo,
        //     .duration = 0.25,
        //     .property = "scaleX",
        //     .target = AnimatableType{ .window = self },
        // });

        // try seq.addProperty(Animatable.Property{
        //     .initial_value = self.scaleY,
        //     .final_value = 1.0,
        //     .easing = ease.OutExpo,
        //     .duration = 0.25,
        //     .property = "scaleY",
        //     .target = AnimatableType{ .window = self },
        // });

        // seq.start();
    }

    pub fn absoluteX(window: *Window) i32 {
        const parent_x = (if (window.parent) |p| p.absoluteX() else 0);
        const window_x = window.current().x;
        var positioner_x: i32 = 0;

        if (window.positioner) |positioner| {
            const rect = positioner.anchor_rect;
            positioner_x = switch (positioner.anchor) {
                .none => rect.x + @divTrunc(rect.width, 2),
                .top => rect.x + @divTrunc(rect.width, 2),
                .bottom => rect.x + @divTrunc(rect.width, 2),
                .left => rect.x,
                .right => rect.x + rect.width,
                .top_left => rect.x,
                .bottom_left => rect.x,
                .top_right => rect.x + rect.width,
                .bottom_right => rect.x + rect.width,
            } + (if (window.parent) |parent| (if (parent.window_geometry) |wg| wg.x else 0) else 0);
        }

        const wg_x = (if (window.window_geometry) |wg| wg.x else 0);

        return parent_x + window_x + positioner_x - wg_x;
    }

    pub fn absoluteY(window: *Window) i32 {
        const parent_y = (if (window.parent) |p| p.absoluteY() else 0);
        const window_y = window.current().y;
        var positioner_y: i32 = 0;

        if (window.positioner) |positioner| {
            const rect = positioner.anchor_rect;
            positioner_y = switch (positioner.anchor) {
                .none => rect.y + @divTrunc(rect.height, 2),
                .top => rect.y,
                .bottom => rect.y + rect.height,
                .left => rect.y + @divTrunc(rect.height, 2),
                .right => rect.y + @divTrunc(rect.height, 2),
                .top_left => rect.y,
                .bottom_left => rect.y + rect.height,
                .top_right => rect.y,
                .bottom_right => rect.y + rect.height,
            } + (if (window.parent) |parent| (if (parent.window_geometry) |wg| wg.y else 0) else 0);
        }

        const wg_y = (if (window.window_geometry) |wg| wg.y else 0);

        return parent_y + window_y + positioner_y - wg_y;
    }

    pub fn frameCallback(window: *Window) !void {
        if (window.ready_for_callback == false) return;
        defer window.ready_for_callback = false;

        while (window.callbacks.readItem()) |wl_callback| {
            try wl_callback.sendDone(@truncate(@as(u64, @intCast(std.time.milliTimestamp()))));
            try window.client.wl_display.sendDeleteId(wl_callback.id);
            window.client.unregister(.{ .wl_callback = wl_callback });
        }
    }

    pub fn root(window: *Window) *Window {
        if (window.parent) |parent| {
            return parent.root();
        } else {
            return window;
        }
    }

    pub fn toplevelWindow(window: *Window) *Window {
        if (window.xdg_toplevel != null) return window;

        if (window.parent) |parent| {
            return parent.root();
        } else {
            return window;
        }
    }

    pub fn toplevelUnderPointer(window: *Window, pointer_x: f64, pointer_y: f64) ?*Window {
        var it = window.backwardIterator();
        while (it.prev()) |w| {
            if (window == w) {
                if (isPointerInside(window, pointer_x, pointer_y)) {
                    return window;
                }
            } else {
                if (w.windowUnderPointer(pointer_x, pointer_y)) |_| {
                    return window;
                }
            }
        }
        return null;
    }

    pub fn windowUnderPointer(window: *Window, pointer_x: f64, pointer_y: f64) ?*Window {
        if (window.popup) |popup| {
            const maybe_popup_window = popup.windowUnderPointer(pointer_x, pointer_y);
            if (maybe_popup_window) |popup_window| {
                return popup_window;
            }
        }

        var it = window.backwardIterator();
        while (it.prev()) |w| {
            if (w == window) {
                if (isPointerInside(window, pointer_x, pointer_y)) {
                    return w;
                }
            } else {
                if (w.windowUnderPointer(pointer_x, pointer_y)) |child| {
                    return child;
                }
            }
        }

        return null;
    }

    fn isPointerInside(window: *Window, x: f64, y: f64) bool {
        if (window.current().input_region) |input_region| {
            return input_region.pointInside(x - @as(f64, @floatFromInt(window.absoluteX())), y - @as(f64, @floatFromInt(window.absoluteY())));
        }

        if (x >= @as(f64, @floatFromInt(window.absoluteX())) and x <= @as(f64, @floatFromInt(window.absoluteX() + window.width))) {
            if (y >= @as(f64, @floatFromInt(window.absoluteY())) and y <= @as(f64, @floatFromInt((window.absoluteY() + window.height)))) {
                return true;
            }
        }
        return false;
    }

    pub fn mouseClick(window: *Window, button: u32, action: u32) !void {
        log.info("mouseClick button = 0x{x}, action = {}, wl_surface@{}", .{ button, action, window.wl_surface.id });
        const client = window.client;
        const wl_pointer = client.wl_pointer orelse return;

        const state = if (action == 0) wl.WlPointer.ButtonState.released else wl.WlPointer.ButtonState.pressed;

        const now: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));
        try wl_pointer.sendButton(client.nextSerial(), now, button, state);
    }

    pub const SubwindowIterator = struct {
        current: ?*Window,
        parent: *Window,

        pub fn next(it: *SubwindowIterator) ?*Window {
            const window = it.current orelse return null;

            if (it.current == it.parent) {
                it.current = window.current().children.next;
            } else {
                it.current = window.current().siblings.next;
            }
            return window;
        }

        pub fn prev(it: *SubwindowIterator) ?*Window {
            const window = it.current orelse return null;

            if (it.current == it.parent) {
                it.current = window.current().children.prev;
            } else {
                it.current = window.current().siblings.prev;
            }
            return window;
        }

        pub fn nextPending(it: *SubwindowIterator) ?*Window {
            const window = it.current orelse return null;

            if (it.current == it.parent) {
                it.current = window.pending().children.next;
            } else {
                it.current = window.pending().siblings.next;
            }
            return window;
        }

        pub fn prevPending(it: *SubwindowIterator) ?*Window {
            const window = it.current orelse return null;

            if (it.current == it.parent) {
                it.current = window.pending().children.prev;
            } else {
                it.current = window.pending().siblings.prev;
            }
            return window;
        }
    };

    pub fn subwindowIterator(window: *Window) SubwindowIterator {
        return SubwindowIterator{
            .current = window,
            .parent = window,
        };
    }

    pub fn forwardIterator(window: *Window) SubwindowIterator {
        var backward_it = window.subwindowIterator();
        var rear: ?*Window = null;
        while (backward_it.prev()) |p| {
            rear = p;
        }

        return SubwindowIterator{
            .current = rear,
            .parent = window,
        };
    }

    pub fn backwardIterator(window: *Window) SubwindowIterator {
        var forward_it = window.subwindowIterator();
        var front: ?*Window = null;
        while (forward_it.next()) |p| {
            front = p;
        }

        return SubwindowIterator{
            .current = front,
            .parent = window,
        };
    }

    // detach window from parent / siblings. Note this detaches the pending state only
    pub fn detach(window: *Window) void {
        const maybe_prev = window.pending().siblings.prev;
        const maybe_next = window.pending().siblings.next;

        if (maybe_prev) |prev| {
            if (prev == window.parent) {
                prev.pending().children.next = maybe_next;
            } else {
                prev.pending().siblings.next = maybe_next;
            }
        }

        if (maybe_next) |next| {
            if (next == window.parent) {
                next.pending().children.prev = maybe_prev;
            } else {
                next.pending().siblings.prev = maybe_prev;
            }
        }

        window.pending().siblings.prev = null;
        window.pending().siblings.next = null;
    }

    pub fn insertAbove(window: *Window, reference: *Self) void {
        if (reference == window.parent) {
            // If we're inserting above our parent we need to set our
            // sibling pointers but the parent's children pointers

            // Save the current next child of parent
            const next = reference.pending().children.next; // should this be current()
            // Set the next child to be our window
            reference.pending().children.next = window;

            // If next is not null set its previous to be our window
            if (next) |n| {
                n.pending().siblings.prev = window;
            }

            window.pending().siblings.next = next;
            window.pending().siblings.prev = reference;
        } else {
            // If we're inserting above a sibling we need to set our
            // sibling pointers and the sibling's sibling pointers
            const next = reference.pending().siblings.next; // should this be current()?
            reference.pending().siblings.next = window;

            // if next is non-null we have two options. Next is either our
            // parent or another sibling. Choose .children or .siblings appropriately.
            if (next) |n| {
                if (n == window.parent) {
                    n.pending().children.prev = window;
                } else {
                    n.pending().siblings.prev = window;
                }
            }

            window.pending().siblings.next = next;
            window.pending().siblings.prev = reference;
        }
    }

    pub fn insertBelow(window: *Window, reference: *Self) void {
        if (reference == window.parent) {
            const prev = reference.pending().children.prev;
            reference.pending().children.prev = window;

            if (prev) |p| {
                p.pending().siblings.next = window;
            }

            window.pending().siblings.next = reference;
            window.pending().siblings.prev = prev;
        } else {
            const prev = reference.pending().siblings.prev;
            reference.pending().siblings.prev = window;

            if (prev) |p| {
                if (p == window.parent) {
                    p.pending().children.next = window;
                } else {
                    p.pending().siblings.next = window;
                }
            }

            window.pending().siblings.next = reference;
            window.pending().siblings.prev = prev;
        }
    }

    pub fn placeAbove(window: *Window, reference: *Self) void {
        window.detach();
        window.insertAbove(reference);
    }

    pub fn placeBelow(window: *Window, reference: *Self) void {
        window.detach();
        window.insertBelow(reference);
    }

    pub fn activate(window: *Window) !void {
        log.info("activate", .{});
        var client = window.client;

        config: {
            const xdg_surface = window.xdg_surface orelse break :config;
            const xdg_toplevel = window.xdg_toplevel orelse break :config;

            var state: [4]u8 = undefined;
            var fbs = std.io.fixedBufferStream(state[0..]);
            try fbs.writer().writeInt(u32, @intFromEnum(wl.XdgToplevel.State.activated), endian);

            const width = if (window.window_geometry) |window_geometry| window_geometry.width else window.width;
            const height = if (window.window_geometry) |window_geometry| window_geometry.height else window.height;

            try xdg_toplevel.sendConfigure(width, height, &state);
            try xdg_surface.sendConfigure(client.nextSerial());
        }

        keyboard: {
            const wl_keyboard = client.wl_keyboard orelse break :keyboard;
            try wl_keyboard.sendEnter(client.nextSerial(), window.wl_surface, &[_]u8{});
        }
    }

    pub fn deactivate(window: *Window) !void {
        log.info("deactivate", .{});
        var client = window.client;

        config: {
            const xdg_surface = window.xdg_surface orelse break :config;
            const xdg_toplevel = window.xdg_toplevel orelse break :config;

            const width = if (window.window_geometry) |window_geometry| window_geometry.width else window.width;
            const height = if (window.window_geometry) |window_geometry| window_geometry.height else window.height;

            try xdg_toplevel.sendConfigure(width, height, &[_]u8{});
            try xdg_surface.sendConfigure(client.nextSerial());
        }

        keyboard: {
            const wl_keyboard = client.wl_keyboard orelse break :keyboard;
            try wl_keyboard.sendLeave(client.nextSerial(), window.wl_surface);
        }
    }

    pub fn pointerEnter(window: *Window, pointer_x: f64, pointer_y: f64) !void {
        const client = window.client;
        const wl_pointer = client.wl_pointer orelse return;

        const x: f64 = @floatFromInt(window.current().x);
        const y: f64 = @floatFromInt(window.current().y);

        try wl_pointer.sendEnter(
            client.nextSerial(),
            window.wl_surface,
            @floatCast(pointer_x - x),
            @floatCast(pointer_y - y),
        );
    }

    pub fn pointerMotion(window: *Window, pointer_x: f64, pointer_y: f64) !void {
        const client = window.client;
        const wl_pointer = client.wl_pointer orelse return;

        const window_x: f64 = @floatFromInt(window.absoluteX());
        const window_y: f64 = @floatFromInt(window.absoluteY());

        try wl_pointer.sendMotion(
            @truncate(@as(u64, @intCast(std.time.milliTimestamp()))),
            @floatCast(pointer_x - window_x),
            @floatCast(pointer_y - window_y),
        );
    }

    pub fn pointerLeave(window: *Window) !void {
        const client = window.client;
        const wl_pointer = client.wl_pointer orelse return;

        try wl_pointer.sendLeave(client.nextSerial(), window.wl_surface);
    }

    pub fn mouseAxis(window: *Window, time: u32, axis: u32, value: f64) !void {
        const client = window.client;
        const wl_pointer = client.wl_pointer orelse return;

        // const now = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        try wl_pointer.sendAxis(time, axis, @floatCast(value));
    }

    pub fn keyboardKey(window: *Window, time: u32, button: u32, action: u32) !void {
        const client = window.client;
        const wl_keyboard = client.wl_keyboard orelse return;

        const state = if (action == 0) wl.WlKeyboard.KeyState.released else wl.WlKeyboard.KeyState.pressed;

        try wl_keyboard.sendKey(client.nextSerial(), time, button, state);

        try wl_keyboard.sendModifiers(
            client.nextSerial(),
            window.client.server.mods_depressed,
            window.client.server.mods_latched,
            window.client.server.mods_locked,
            window.client.server.mods_group,
        );
    }

    /// Deinitialise window.
    ///
    /// - Detaches the window from any sibling windows
    /// - Removes the window from its view (where one exists).
    /// - Releases the window's texture (where one exists).
    pub fn deinit(window: *Window) void {
        log.info("deinit (client@{} wl_surface@{})", .{ window.client.conn.stream.handle, window.wl_surface.id });
        // Before doing anything else, such as deiniting the parent
        // detach this surface from its siblings
        window.detach(); // maybe we also need to detach current, i.e. window.detachCurrent()?

        if (window.xdg_popup_id != null) {
            if (window.parent) |parent| {
                parent.popup = null;
            }
        }

        if (window.positioner) |positioner| {
            positioner.deinit();
        }

        if (window.view) |view| {
            view.remove(window);
            if (view.active_window == window) {
                view.active_window = null;
            }
            if (view.pointer_window == window) {
                view.pointer_window = null;
            }
        }

        if (window.texture) |texture| {
            window.texture = null;
            // Note that while this can fail, we're doing
            // the bits that can fail after deinitialising
            // enough so that this window could be reused
            _ = Renderer.releaseTexture(texture) catch {};
        }
    }
};

pub fn debug(window: ?*Window) void {
    if (window) |self| {
        var next: ?usize = null;
        var prev: ?usize = null;

        if (self.toplevel.next) |toplevel_next| {
            next = toplevel_next.index;
        }

        if (self.toplevel.prev) |toplevel_prev| {
            prev = toplevel_prev.index;
        }

        std.log.warn("debug: {} <-- window[{}, {}] --> {}\n", .{ prev, self.index, self.wl_surface_id, next });
    } else {
        std.log.warn("debug: null\n", .{});
    }
}

pub fn debug_sibling(window: ?*Window) void {
    if (window) |self| {
        var next: ?usize = null;
        var prev: ?usize = null;

        if (self.current().siblings.next) |sibling_next| {
            next = sibling_next.index;
        }

        if (self.current().siblings.prev) |sibling_prev| {
            prev = sibling_prev.index;
        }

        var next_child: ?usize = null;
        var prev_child: ?usize = null;

        if (self.current().children.next) |children_next| {
            next_child = children_next.index;
        }

        if (self.current().children.prev) |children_prev| {
            prev_child = children_prev.index;
        }

        std.log.warn("debug sibling: {} <-- window[{}, @{}] --> {}\n", .{ prev, self.index, self.wl_surface_id, next });
        std.log.warn("debug children: {} <-- window[{}, @{}] --> {}\n", .{ prev_child, self.index, self.wl_surface_id, next_child });
    } else {
        std.log.warn("debug_sibling: null\n", .{});
    }
}

pub fn debug_sibling_pending(window: ?*Window) void {
    if (window) |self| {
        var next: ?usize = null;
        var prev: ?usize = null;

        if (self.pending().siblings.next) |sibling_next| {
            next = sibling_next.index;
        }

        if (self.pending().siblings.prev) |sibling_prev| {
            prev = sibling_prev.index;
        }

        var next_child: ?usize = null;
        var prev_child: ?usize = null;

        if (self.pending().children.next) |children_next| {
            next_child = children_next.index;
        }

        if (self.pending().children.prev) |children_prev| {
            prev_child = children_prev.index;
        }

        std.log.warn("debug sibling (pending): {} <-- window[{}, @{}] --> {}\n", .{ prev, self.index, self.wl_surface_id, next });
        std.log.warn("debug children (pending): {} <-- window[{}, @{}] --> {}\n", .{ prev_child, self.index, self.wl_surface_id, next_child });
    } else {
        std.log.warn("debug_sibling (pending): null\n", .{});
    }
}

pub const XdgOperation = enum {
    Maximize,
    Unmaximize,
};

pub const XdgConfiguration = struct {
    serial: u32,
    operation: XdgOperation,
};

const BufferedState = struct {
    sync: bool = false,

    siblings: Link = Link{},

    x: i32 = 0,
    y: i32 = 0,
    scale: i32 = 1,
    transform: wl.WlOutput.Transform = .normal,

    input_region: ?*Region = null,
    opaque_region: ?*Region = null,

    min_width: ?i32 = null,
    min_height: ?i32 = null,
    max_width: ?i32 = null,
    max_height: ?i32 = null,

    children: Link = Link{},

    const Self = @This();
};

pub const Link = struct {
    prev: ?*Window = null,
    next: ?*Window = null,
    mark: bool = false,

    pub fn unanchored(link: Link) bool {
        return (link.prev == null) and (link.next == null);
    }

    pub fn deinit(link: *Link) void {
        if (link.next) |next| {
            next.toplevel.prev = link.prev;
        }

        if (link.prev) |prev| {
            prev.toplevel.next = link.next;
        }

        link.prev = null;
        link.next = null;
    }
};

pub const Cursor = struct {
    hotspot_x: i32,
    hotspot_y: i32,
};
