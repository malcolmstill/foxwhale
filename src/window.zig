const std = @import("std");
const math = std.math;
const prot = @import("protocols.zig");
const Renderer = @import("renderer.zig").Renderer;
const compositor = @import("compositor.zig");
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const Region = @import("region.zig").Region;
const Positioner = @import("positioner.zig").Positioner;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const View = @import("view.zig").View;
const Mat4x4 = @import("math.zig").Mat4x4;
const Animatable = @import("animatable.zig").Animatable;
const AnimatableType = @import("animatable.zig").AnimatableType;
const ease = @import("ease.zig");

const MAX_WINDOWS = 512;
pub var WINDOWS: [MAX_WINDOWS]Window = undefined;

pub const XdgConfigurations = LinearFifo(XdgConfiguration, LinearFifoBufferType{ .Static = 32 });

pub const Window = struct {
    index: usize = 0,
    in_use: bool = false,
    client: *Client,

    mapped: bool = false,
    view: ?*View,

    parent: ?*Window,
    popup: ?*Window,

    toplevel: Link,

    ready_for_callback: bool = false,

    texture: ?u32,
    width: i32,
    height: i32,

    // Animatable
    scaleX: f32 = 1.0,
    scaleY: f32 = 1.0,
    originX: f32 = 0.0,
    originY: f32 = 0.0,

    first_configure: bool = false,
    first_buffer: bool = false,

    wl_surface_id: u32,
    wl_buffer_id: ?u32,
    xdg_surface_id: ?u32,
    xdg_toplevel_id: ?u32,
    xdg_popup_id: ?u32,
    wl_subsurface_id: ?u32,

    positioner: ?*Positioner,

    window_geometry: ?Rectangle,

    synchronized: bool = false,
    state: [2]BufferedState = undefined,
    stateIndex: u1 = 0,

    // When not null, Rectangle defines the OLD unmaximised geometry
    maximized: ?Rectangle,
    xdg_configurations: XdgConfigurations,

    title: [128]u8 = undefined,
    app_id: [256]u8 = undefined,
    callbacks: LinearFifo(u32, LinearFifoBufferType{ .Static = 32 }),

    const Self = @This();

    // flip double-buffered state
    pub fn flip(self: *Self) void {
        // std.log.warn("flipping: {}\n", .{self.index});
        self.stateIndex +%= 1;
        if (self.current().input_region != self.pending().input_region) {
            if (self.pending().input_region) |input_region| {
                try input_region.deinit();
            }
        }

        if (self.current().opaque_region != self.pending().opaque_region) {
            if (self.pending().opaque_region) |opaque_region| {
                try opaque_region.deinit();
            }
        }
        self.pending().* = self.current().*;

        // flip synchronized subwindows above self
        var forward_it = self.subwindowIterator();
        while (forward_it.nextPending()) |subwindow| {
            if (subwindow != self and subwindow.synchronized) {
                subwindow.flip();
            }
        }

        // flip synchronized subwindows below self
        var backward_it = self.subwindowIterator();
        while (backward_it.prevPending()) |subwindow| {
            if (subwindow != self and subwindow.synchronized) {
                subwindow.flip();
            }
        }
    }

    pub fn current(self: *Self) *BufferedState {
        return &self.state[self.stateIndex];
    }

    pub fn pending(self: *Self) *BufferedState {
        return &self.state[self.stateIndex +% 1];
    }

    pub fn render(self: *Self, output_width: i32, output_height: i32, renderer: *Renderer, x: i32, y: i32) anyerror!void {
        var it = self.forwardIterator();
        while (it.next()) |window| {
            window.ready_for_callback = true;
            if (window == self) {
                const texture = window.texture orelse continue; // TODO: maybe we should not render subwindows if parent window not ready
                const program = try renderer.useProgram("window");

                const win_x = window.current().x;
                const win_y = window.current().y;
                const abs_x = @intToFloat(f32, window.absoluteX() + x);
                const abs_y = @intToFloat(f32, window.absoluteY() + y);

                if (window.parent) |parent| {
                    try Renderer.setUniformMatrix(program, "scale", Mat4x4(f32).scale([_]f32{ parent.scaleX, parent.scaleY, 1.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "translate", Mat4x4(f32).translate([_]f32{ abs_x, abs_y, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "origin", Mat4x4(f32).translate([_]f32{ -parent.originX + @intToFloat(f32, win_x), -parent.originY + @intToFloat(f32, win_y), 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "originInverse", Mat4x4(f32).translate([_]f32{ parent.originX - @intToFloat(f32, win_x), parent.originY - @intToFloat(f32, win_y), 0.0, 1.0 }).data);
                    try Renderer.setUniformFloat(program, "opacity", 1.0);
                } else {
                    try Renderer.setUniformMatrix(program, "scale", Mat4x4(f32).scale([_]f32{ self.scaleX, self.scaleY, 1.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "translate", Mat4x4(f32).translate([_]f32{ abs_x, abs_y, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "origin", Mat4x4(f32).translate([_]f32{ -self.originX, -self.originY, 0.0, 1.0 }).data);
                    try Renderer.setUniformMatrix(program, "originInverse", Mat4x4(f32).translate([_]f32{ self.originX, self.originY, 0.0, 1.0 }).data);
                    try Renderer.setUniformFloat(program, "opacity", 1.0);
                }

                try renderer.renderSurface(output_width, output_height, program, texture, window.width, window.height);
            } else {
                try window.render(output_width, output_height, renderer, x, y);
            }
        }

        if (self.popup) |popup| {
            try popup.render(output_width, output_height, renderer, x, y);
        }
    }

    pub fn firstCommit(self: *Self) !void {
        self.originX = @intToFloat(f32, self.width) / 2.0;
        self.originY = @intToFloat(f32, self.height) / 2.0;
        self.scaleX = 0.0;
        self.scaleY = 6.0 / @intToFloat(f32, self.height);

        const seq = try compositor.COMPOSITOR.animations.addSequential();
        try seq.addProperty(Animatable.Property{
            .initial_value = self.scaleX,
            .final_value = 1.0,
            .easing = ease.OutExpo,
            .duration = 0.25,
            .property = "scaleX",
            .target = AnimatableType{ .window = self },
        });

        try seq.addProperty(Animatable.Property{
            .initial_value = self.scaleY,
            .final_value = 1.0,
            .easing = ease.OutExpo,
            .duration = 0.25,
            .property = "scaleY",
            .target = AnimatableType{ .window = self },
        });

        seq.start();
    }

    pub fn absoluteX(self: *Self) i32 {
        var parent_x = (if (self.parent) |p| p.absoluteX() else 0);
        var self_x = self.current().x;
        var positioner_x: i32 = 0;

        if (self.positioner) |positioner| {
            var rect = positioner.anchor_rect;
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
            } + (if (self.parent) |parent| (if (parent.window_geometry) |wg| wg.x else 0) else 0);
        }

        var wg_x = (if (self.window_geometry) |wg| wg.x else 0);

        return parent_x + self_x + positioner_x - wg_x;
    }

    pub fn absoluteY(self: *Self) i32 {
        var parent_y = (if (self.parent) |p| p.absoluteY() else 0);
        var self_y = self.current().y;
        var positioner_y: i32 = 0;

        if (self.positioner) |positioner| {
            var rect = positioner.anchor_rect;
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
            } + (if (self.parent) |parent| (if (parent.window_geometry) |wg| wg.y else 0) else 0);
        }

        var wg_y = (if (self.window_geometry) |wg| wg.y else 0);

        return parent_y + self_y + positioner_y - wg_y;
    }

    pub fn frameCallback(self: *Self) !void {
        if (self.ready_for_callback == false) {
            return;
        }

        while (self.callbacks.readItem()) |wl_callback_id| {
            const wl_callback = self.client.context.get(wl_callback_id) orelse return error.CallbackIdNotFound;
            try prot.wl_callback_send_done(wl_callback, @truncate(u32, @intCast(u64, std.time.milliTimestamp())));
            try self.client.context.unregister(wl_callback);
            try prot.wl_display_send_delete_id(self.client.context.client.wl_display, wl_callback_id);
        }

        self.ready_for_callback = false;
    }

    pub fn root(self: *Window) *Window {
        if (self.parent) |parent| {
            return parent.root();
        } else {
            return self;
        }
    }

    pub fn toplevelWindow(self: *Window) *Window {
        if (self.xdg_toplevel_id != null) {
            return self;
        }

        if (self.parent) |parent| {
            return parent.root();
        } else {
            return self;
        }
    }

    pub fn toplevelUnderPointer(self: *Self, pointer_x: f64, pointer_y: f64) ?*Window {
        var it = self.backwardIterator();
        while (it.prev()) |window| {
            if (self == window) {
                if (isPointerInside(self, pointer_x, pointer_y)) {
                    return self;
                }
            } else {
                if (window.windowUnderPointer(pointer_x, pointer_y)) |_| {
                    return self;
                }
            }
        }
        return null;
    }

    pub fn windowUnderPointer(self: *Self, pointer_x: f64, pointer_y: f64) ?*Window {
        if (self.popup) |popup| {
            var maybe_popup_window = popup.windowUnderPointer(pointer_x, pointer_y);
            if (maybe_popup_window) |popup_window| {
                return popup_window;
            }
        }

        var it = self.backwardIterator();
        while (it.prev()) |window| {
            if (self == window) {
                if (isPointerInside(self, pointer_x, pointer_y)) {
                    return window;
                }
            } else {
                if (window.windowUnderPointer(pointer_x, pointer_y)) |child| {
                    return child;
                }
            }
        }

        return null;
    }

    fn isPointerInside(self: *Self, x: f64, y: f64) bool {
        if (self.current().input_region) |input_region| {
            return input_region.pointInside(x - @intToFloat(f64, self.absoluteX()), y - @intToFloat(f64, self.absoluteY()));
        }

        if (x >= @intToFloat(f64, self.absoluteX()) and x <= @intToFloat(f64, (self.absoluteX() + self.width))) {
            if (y >= @intToFloat(f64, self.absoluteY()) and y <= @intToFloat(f64, (self.absoluteY() + self.height))) {
                return true;
            }
        }
        return false;
    }

    pub fn mouseClick(self: *Self, button: u32, action: u32) !void {
        const client = self.client;
        const wl_pointer_id = client.wl_pointer_id orelse return;
        const wl_pointer = client.context.get(wl_pointer_id) orelse return;

        const now = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        try prot.wl_pointer_send_button(wl_pointer, client.nextSerial(), now, button, action);
    }

    pub const SubwindowIterator = struct {
        current: ?*Window,
        parent: *Window,

        pub fn next(self: *SubwindowIterator) ?*Window {
            const window = self.current orelse return null;

            if (self.current == self.parent) {
                self.current = window.current().children.next;
            } else {
                self.current = window.current().siblings.next;
            }
            return window;
        }

        pub fn prev(self: *SubwindowIterator) ?*Window {
            const window = self.current orelse return null;

            if (self.current == self.parent) {
                self.current = window.current().children.prev;
            } else {
                self.current = window.current().siblings.prev;
            }
            return window;
        }

        pub fn nextPending(self: *SubwindowIterator) ?*Window {
            const window = self.current orelse return null;

            if (self.current == self.parent) {
                self.current = window.pending().children.next;
            } else {
                self.current = window.pending().siblings.next;
            }
            return window;
        }

        pub fn prevPending(self: *SubwindowIterator) ?*Window {
            const window = self.current orelse return null;

            if (self.current == self.parent) {
                self.current = window.pending().children.prev;
            } else {
                self.current = window.pending().siblings.prev;
            }
            return window;
        }
    };

    pub fn subwindowIterator(self: *Self) SubwindowIterator {
        return SubwindowIterator{
            .current = self,
            .parent = self,
        };
    }

    pub fn forwardIterator(self: *Self) SubwindowIterator {
        var backward_it = self.subwindowIterator();
        var rear: ?*Window = null;
        while (backward_it.prev()) |p| {
            rear = p;
        }

        return SubwindowIterator{
            .current = rear,
            .parent = self,
        };
    }

    pub fn backwardIterator(self: *Self) SubwindowIterator {
        var forward_it = self.subwindowIterator();
        var front: ?*Window = null;
        while (forward_it.next()) |p| {
            front = p;
        }

        return SubwindowIterator{
            .current = front,
            .parent = self,
        };
    }

    // detach window from parent / siblings. Note this detaches the pending state only
    pub fn detach(self: *Self) void {
        var maybe_prev = self.pending().siblings.prev;
        var maybe_next = self.pending().siblings.next;

        if (maybe_prev) |prev| {
            if (prev == self.parent) {
                prev.pending().children.next = maybe_next;
            } else {
                prev.pending().siblings.next = maybe_next;
            }
        }

        if (maybe_next) |next| {
            if (next == self.parent) {
                next.pending().children.prev = maybe_prev;
            } else {
                next.pending().siblings.prev = maybe_prev;
            }
        }

        self.pending().siblings.prev = null;
        self.pending().siblings.next = null;
    }

    pub fn insertAbove(self: *Self, reference: *Self) void {
        if (reference == self.parent) {
            // If we're inserting above our parent we need to set our
            // sibling pointers but the parent's children pointers

            // Save the current next child of parent
            var next = reference.pending().children.next; // should this be current()
            // Set the next child to be our window
            reference.pending().children.next = self;

            // If next is not null set its previous to be our window
            if (next) |n| {
                n.pending().siblings.prev = self;
            }

            self.pending().siblings.next = next;
            self.pending().siblings.prev = reference;
        } else {
            // If we're inserting above a sibling we need to set our
            // sibling pointers and the sibling's sibling pointers
            var next = reference.pending().siblings.next; // should this be current()?
            reference.pending().siblings.next = self;

            // if next is non-null we have two options. Next is either our
            // parent or another sibling. Choose .children or .siblings appropriately.
            if (next) |n| {
                if (n == self.parent) {
                    n.pending().children.prev = self;
                } else {
                    n.pending().siblings.prev = self;
                }
            }

            self.pending().siblings.next = next;
            self.pending().siblings.prev = reference;
        }
    }

    pub fn insertBelow(self: *Self, reference: *Self) void {
        if (reference == self.parent) {
            var prev = reference.pending().children.prev;
            reference.pending().children.prev = self;

            if (prev) |p| {
                p.pending().siblings.next = self;
            }

            self.pending().siblings.next = reference;
            self.pending().siblings.prev = prev;
        } else {
            var prev = reference.pending().siblings.prev;
            reference.pending().siblings.prev = self;

            if (prev) |p| {
                if (p == self.parent) {
                    p.pending().children.next = self;
                } else {
                    p.pending().siblings.next = self;
                }
            }

            self.pending().siblings.next = reference;
            self.pending().siblings.prev = prev;
        }
    }

    pub fn placeAbove(self: *Self, reference: *Self) void {
        self.detach();
        self.insertAbove(reference);
    }

    pub fn placeBelow(self: *Self, reference: *Self) void {
        self.detach();
        self.insertBelow(reference);
    }

    pub fn activate(self: *Self) !void {
        var client = self.client;

        config: {
            const xdg_surface_id = self.xdg_surface_id orelse break :config;
            const xdg_surface = client.context.get(xdg_surface_id) orelse break :config;
            const xdg_toplevel_id = self.xdg_toplevel_id orelse break :config;
            const xdg_toplevel = client.context.get(xdg_toplevel_id) orelse break :config;

            var state: [1]u32 = [_]u32{@enumToInt(prot.xdg_toplevel_state.activated)};
            if (self.window_geometry) |window_geometry| {
                try prot.xdg_toplevel_send_configure(xdg_toplevel, window_geometry.width, window_geometry.height, &state);
            } else {
                try prot.xdg_toplevel_send_configure(xdg_toplevel, self.width, self.height, &state);
            }
            try prot.xdg_surface_send_configure(xdg_surface, client.nextSerial());
        }

        keyboard: {
            const wl_keyboard_id = client.wl_keyboard_id orelse break :keyboard;
            const wl_keyboard = client.context.get(wl_keyboard_id) orelse break :keyboard;

            try prot.wl_keyboard_send_enter(wl_keyboard, client.nextSerial(), self.wl_surface_id, &[_]u32{});
        }
    }

    pub fn deactivate(self: *Self) !void {
        var client = self.client;

        config: {
            const xdg_surface_id = self.xdg_surface_id orelse break :config;
            const xdg_surface = client.context.get(xdg_surface_id) orelse break :config;
            const xdg_toplevel_id = self.xdg_toplevel_id orelse break :config;
            const xdg_toplevel = client.context.get(xdg_toplevel_id) orelse break :config;

            if (self.window_geometry) |window_geometry| {
                try prot.xdg_toplevel_send_configure(xdg_toplevel, window_geometry.width, window_geometry.height, &[_]u32{});
            } else {
                try prot.xdg_toplevel_send_configure(xdg_toplevel, self.width, self.height, &[_]u32{});
            }
            try prot.xdg_surface_send_configure(xdg_surface, client.nextSerial());
        }

        keyboard: {
            const wl_keyboard_id = client.wl_keyboard_id orelse break :keyboard;
            const wl_keyboard = client.context.get(wl_keyboard_id) orelse break :keyboard;

            try prot.wl_keyboard_send_leave(wl_keyboard, client.nextSerial(), self.wl_surface_id);
        }
    }

    pub fn pointerEnter(self: *Self, pointer_x: f64, pointer_y: f64) !void {
        const client = self.client;
        const wl_pointer_id = client.wl_pointer_id orelse return;
        const wl_pointer = client.context.get(wl_pointer_id) orelse return;

        try prot.wl_pointer_send_enter(wl_pointer, client.nextSerial(), self.wl_surface_id, @floatCast(f32, pointer_x - @intToFloat(f64, self.current().x)), @floatCast(f32, pointer_y - @intToFloat(f64, self.current().y)));
    }

    pub fn pointerMotion(self: *Self, pointer_x: f64, pointer_y: f64) !void {
        const client = self.client;
        const wl_pointer_id = client.wl_pointer_id orelse return;
        const wl_pointer = client.context.get(wl_pointer_id) orelse return;

        try prot.wl_pointer_send_motion(
            wl_pointer,
            @truncate(u32, @intCast(u64, std.time.milliTimestamp())),
            @floatCast(f32, pointer_x - @intToFloat(f64, self.absoluteX())),
            @floatCast(f32, pointer_y - @intToFloat(f64, self.absoluteY())),
        );
    }

    pub fn pointerLeave(self: *Self) !void {
        const client = self.client;
        const wl_pointer_id = client.wl_pointer_id orelse return;
        const wl_pointer = client.context.get(wl_pointer_id) orelse return;

        try prot.wl_pointer_send_leave(
            wl_pointer,
            client.nextSerial(),
            self.wl_surface_id,
        );
    }

    pub fn mouseAxis(self: *Self, time: u32, axis: u32, value: f64) !void {
        const client = self.client;
        const wl_pointer_id = client.wl_pointer_id orelse return;
        const wl_pointer = client.context.get(wl_pointer_id) orelse return;

        // const now = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        try prot.wl_pointer_send_axis(wl_pointer, time, axis, @floatCast(f32, value));
    }

    pub fn keyboardKey(self: *Self, time: u32, button: u32, action: u32) !void {
        const client = self.client;
        const wl_keyboard_id = client.wl_keyboard_id orelse return;
        const wl_keyboard = client.context.get(wl_keyboard_id) orelse return;

        try prot.wl_keyboard_send_key(
            wl_keyboard,
            client.nextSerial(),
            time,
            button,
            action,
        );

        try prot.wl_keyboard_send_modifiers(
            wl_keyboard,
            client.nextSerial(),
            compositor.COMPOSITOR.mods_depressed,
            compositor.COMPOSITOR.mods_latched,
            compositor.COMPOSITOR.mods_locked,
            compositor.COMPOSITOR.mods_group,
        );
    }

    pub fn deinit(self: *Self) !void {
        std.log.warn("release window {}\n", .{self.index});
        self.in_use = false;

        // Before doing anything else, such as deiniting the parent
        // detach this surface from its siblings
        self.detach(); // maybe we also need to detach current, i.e. self.detachCurrent()?

        if (self.xdg_popup_id != null) {
            if (self.parent) |parent| {
                parent.popup = null;
            }
        }
        self.parent = null;
        self.popup = null;

        self.wl_buffer_id = null;
        self.xdg_surface_id = null;
        self.xdg_toplevel_id = null;
        self.xdg_popup_id = null;
        self.wl_subsurface_id = null;

        if (self.positioner) |positioner| {
            try positioner.deinit();
        }
        self.positioner = null;
        self.window_geometry = null;

        self.ready_for_callback = false;

        self.synchronized = false;

        if (self.view) |view| {
            view.remove(self);
            if (view.active_window == self) {
                view.active_window = null;
            }
            if (view.pointer_window == self) {
                view.pointer_window = null;
            }
        }
        self.view = null;
        self.mapped = false;

        self.state[0].deinit();
        self.state[1].deinit();

        if (self.texture) |texture| {
            self.texture = null;
            // Note that while this can fail, we're doing
            // the bits that can fail after deinitialising
            // enough so that this window could be reused
            try Renderer.releaseTexture(texture);
        }
    }
};

pub fn newWindow(client: *Client, wl_surface_id: u32) !*Window {
    var i: usize = 0;
    while (i < MAX_WINDOWS) {
        var window: *Window = &WINDOWS[i];
        if (window.in_use == false) {
            window.index = i;
            window.in_use = true;
            window.client = client;

            window.wl_surface_id = wl_surface_id;
            window.wl_buffer_id = null;
            window.xdg_surface_id = null;
            window.xdg_toplevel_id = null;

            window.callbacks = LinearFifo(u32, LinearFifoBufferType{ .Static = 32 }).init();

            window.texture = null;
            window.width = 0;
            window.height = 0;

            window.first_configure = false;
            window.first_buffer = false;

            window.scaleX = 1.0;
            window.scaleY = 1.0;
            window.originX = 0.0;
            window.originY = 0.0;

            window.state[0].deinit();
            window.state[1].deinit();

            return window;
        } else {
            i = i + 1;
            continue;
        }
    }

    return error.WindowsExhausted;
}

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

    siblings: Link,

    x: i32 = 0,
    y: i32 = 0,
    scale: i32 = 1,

    input_region: ?*Region,
    opaque_region: ?*Region,

    min_width: ?i32,
    min_height: ?i32,
    max_width: ?i32,
    max_height: ?i32,

    children: Link,

    const Self = @This();

    fn deinit(self: *Self) void {
        self.sync = false;

        self.siblings.prev = null;
        self.siblings.next = null;

        self.x = 0;
        self.y = 0;
        self.scale = 1;

        self.input_region = null;
        self.opaque_region = null;

        self.min_width = null;
        self.min_height = null;
        self.max_width = null;
        self.max_height = null;

        self.children.prev = null;
        self.children.next = null;
    }
};

pub fn releaseWindows(client: *Client) !void {
    var i: usize = 0;
    while (i < MAX_WINDOWS) {
        var window: *Window = &WINDOWS[i];
        if (window.in_use and window.client == client) {
            try window.deinit();
        }
        i = i + 1;
    }
}

pub const Link = struct {
    prev: ?*Window,
    next: ?*Window,
    mark: bool,

    pub fn unanchored(self: Link) bool {
        return (self.prev == null) and (self.next == null);
    }

    pub fn deinit(self: *Link) void {
        if (self.next) |next| {
            next.toplevel.prev = self.prev;
        }

        if (self.prev) |prev| {
            prev.toplevel.next = self.next;
        }

        self.prev = null;
        self.next = null;
    }
};

pub const Cursor = struct {
    hotspot_x: i32,
    hotspot_y: i32,
};

test "Window + View" {
    var c: Client = undefined;
    var v: View = View{
        .top = null,
        .pointer_window = null,
        .active_window = null,
        .focus = .Click,
    };

    var back = v.back();
    std.debug.assert(back == null);

    var w1 = try newWindow(&c, 1);
    v.push(w1);
    std.debug.assert(v.top == w1);

    back = v.back();
    std.debug.assert(back == w1);

    std.debug.assert(w1.toplevel.prev == null);
    std.debug.assert(w1.toplevel.next == null);

    var w2 = try newWindow(&c, 2);
    v.push(w2);
    std.debug.assert(v.top == w2);

    back = v.back();
    std.debug.assert(back == w1);

    std.debug.assert(w1.toplevel.prev == null);
    std.debug.assert(w1.toplevel.next == w2);

    std.debug.assert(w2.toplevel.prev == w1);
    std.debug.assert(w2.toplevel.next == null);

    var w3 = try newWindow(&c, 3);
    v.push(w3);
    std.debug.assert(v.top == w3);

    back = v.back();
    std.debug.assert(back == w1);

    std.debug.assert(w1.toplevel.prev == null);
    std.debug.assert(w1.toplevel.next == w2);

    std.debug.assert(w2.toplevel.prev == w1);
    std.debug.assert(w2.toplevel.next == w3);

    std.debug.assert(w3.toplevel.prev == w2);
    std.debug.assert(w3.toplevel.next == null);

    // Remove middle window
    v.remove(w2);
    std.debug.assert(v.top == w3);

    back = v.back();
    std.debug.assert(back == w1);

    std.debug.assert(w1.toplevel.prev == null);
    std.debug.assert(w1.toplevel.next == w3);

    std.debug.assert(w3.toplevel.prev == w1);
    std.debug.assert(w3.toplevel.next == null);

    v.remove(w3);
    std.debug.assert(v.top == w1);

    back = v.back();
    std.debug.assert(back == w1);

    std.debug.assert(w1.toplevel.prev == null);
    std.debug.assert(w1.toplevel.next == null);

    v.remove(w1);

    back = v.back();
    std.debug.assert(back == null);
}
