const std = @import("std");
const prot = @import("protocols.zig");
const renderer = @import("renderer.zig");
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const View = @import("view.zig").View;

const MAX_WINDOWS = 512;
pub var WINDOWS: [MAX_WINDOWS]Window = undefined;

pub const Window = struct {
    index: usize = 0,
    in_use: bool = false,
    client: *Client,

    mapped: bool = false,
    view: ?*View,

    parent: ?*Window,

    ready_for_callback: bool = false,

    texture: ?u32,
    width: i32,
    height: i32,

    wl_surface_id: u32,
    wl_buffer_id: ?u32,
    xdg_surface_id: ?u32,
    xdg_toplevel_id: ?u32,
    wl_subsurface_id: ?u32,

    window_geometry: ?Rectangle,

    state: [2]BufferedState = undefined,
    stateIndex: u1 = 0,

    top_link: Link,

    title: [128]u8 = undefined,
    app_id: [256]u8 = undefined,
    callbacks: LinearFifo(u32, LinearFifoBufferType{ .Static = 32 }),

    const Self = @This();

    // flip double-buffered state
    pub fn flip(self: *Self) void {
        self.stateIndex +%= 1;
        self.pending().* = self.current().*;
    }

    pub fn current(self: *Self) *BufferedState {
        return &self.state[self.stateIndex];
    }

    pub fn pending(self: *Self) *BufferedState {
        return &self.state[self.stateIndex +% 1];
    }

    pub fn render(self: *Self) anyerror!void {
        var it = self.forwardIterator();
        while(it.next()) |window| {
            window.ready_for_callback = true;
            if (window == self) {
                if (window.texture) |texture| {
                    try renderer.scale(1.0, 1.0);
                    try renderer.translate(@intToFloat(f32, window.absoluteX()), @intToFloat(f32, window.absoluteY()));
                    try renderer.setUniformMatrix(renderer.PROGRAM, "origin", renderer.identity);
                    try renderer.setUniformMatrix(renderer.PROGRAM, "originInverse", renderer.identity);
                    try renderer.setUniformFloat(renderer.PROGRAM, "opacity", 0.8);
                    renderer.setGeometry(window);
                    try renderer.renderSurface(renderer.PROGRAM, texture);
                }
            } else {
                try window.render();
            }
        }
    }

    pub fn absoluteX(self: *Self) i32 {
        return self.current().x + (if (self.parent) |p| p.absoluteX() else 0);
    }

    pub fn absoluteY(self: *Self) i32 {
        return self.current().y + (if (self.parent) |p| p.absoluteY() else 0);
    }

    pub fn frameCallback(self: *Self) !void {
        if (self.ready_for_callback == false) {
            return;
        }

        while(self.callbacks.readItem()) |wl_callback_id| {
            if (self.client.context.get(wl_callback_id)) |wl_callback| {
                try prot.wl_callback_send_done(wl_callback.*, @truncate(u32, std.time.milliTimestamp()));
                try self.client.context.unregister(wl_callback.*);
                try prot.wl_display_send_delete_id(self.client.context.client.wl_display, wl_callback_id);
            } else {
                return error.CallbackIdNotFound;
            }
        } else |err| {

        }

        self.ready_for_callback = false;
    }

    pub fn windowUnderPointer(self: *Self, pointer_x: f64, pointer_y: f64) ?*Window {
        var it = self.backwardIterator();
        while(it.prev()) |window| {
            if (self == window) {
                var x = @floatToInt(i32, pointer_x);
                var y = @floatToInt(i32, pointer_y);
                if (x >= window.absoluteX() and x <= (window.absoluteX() + window.width)) {
                    if (y >= window.absoluteY() and y <= (window.absoluteY() + window.height)) {
                        return window;
                    }
                }
            } else {
                if (window.windowUnderPointer(pointer_x, pointer_y)) |child| {
                    return child;
                }
            }
        }
        return null;
    }

    pub const SubwindowIterator = struct {
        current: ?*Window,
        parent: ?*Window,

        pub fn next(self: *SubwindowIterator) ?*Window {
            if (self.current) |window| {
                if (self.current == self.parent) {
                    self.current = window.current().children.next;
                } else {
                    self.current = window.current().siblings.next;
                }
                return window;
            }

            return null;
        }

        pub fn prev(self: *SubwindowIterator) ?*Window {
            if (self.current) |window| {
                if (self.current == self.parent) {
                    self.current = window.current().children.prev;
                } else {
                    self.current = window.current().siblings.prev;
                }
                return window;
            }

            return null;
        }
    };

    pub fn subwindowIterator(self: *Self) SubwindowIterator {
        return SubwindowIterator {
            .current = self,
            .parent = self,
        };
    }

    pub fn forwardIterator(self: *Self) SubwindowIterator {
        var backward_it = self.subwindowIterator();
        var rear: ?*Window = null;
        while(backward_it.prev()) |p| {
            rear = p;
        }

        return SubwindowIterator {
            .current = rear,
            .parent = self,
        };
    }

    pub fn backwardIterator(self: *Self) SubwindowIterator {
        var forward_it = self.subwindowIterator();
        var front: ?*Window = null;
        while(forward_it.next()) |p| {
            front = p;
        }

        return SubwindowIterator {
            .current = front,
            .parent = self,
        };
    }

    pub fn detach(self: *Self) void {
        var prev = self.pending().siblings.prev;
        var next = self.pending().siblings.next;

        if (prev) |p| {
            if (p == self.parent) {
                if (next) |n| {
                    p.pending().children.next = n;
                } else {
                    p.pending().children.next = null;
                }
            } else {
                if (next) |n| {
                    p.pending().siblings.next = n;
                } else {
                    p.pending().siblings.next = null;
                }
            }
        }

        if (next) |n| {
            if (n == self.parent) {
                if (prev) |p| {
                    n.pending().children.prev = p;
                } else {
                    n.pending().children.prev = null;
                }
            } else {
                if (prev) |p| {
                    n.pending().siblings.prev = p;
                } else {
                    n.pending().siblings.prev = null;
                }
            }
        }

        self.pending().siblings.prev = null;
        self.pending().siblings.next = null;
    }

    pub fn insertAbove(self: *Self, reference: *Self) void {
        if (reference == self.parent) {
            var next = reference.pending().children.next;
            reference.pending().children.next = self;

            if (next) |n| {
                n.pending().siblings.prev = self;
            }

            self.pending().siblings.next = next;
            self.pending().siblings.prev = reference;
        } else {
            var next = reference.pending().siblings.next;
            reference.pending().siblings.next = self;

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

    pub fn deinit(self: *Self) !void {
        std.debug.warn("release window\n", .{});
        self.in_use = false;

        self.parent = null;

        self.wl_buffer_id = null;
        self.xdg_surface_id = null;
        self.xdg_toplevel_id = null;
        self.wl_subsurface_id = null;

        self.state[0].deinit();
        self.state[1].deinit();

        self.ready_for_callback = false;

        if (self.view) |v| {
            if (v.top == self) {
                v.top = self.top_link.prev;
            }
        }
        self.view = null;
        self.top_link.deinit();
        self.mapped = false;

        if (self.texture) |texture| {
            self.texture = null;
            // Note that while this can fail, we're doing
            // the bits that can fail after deinitialising
            // enough so that this window could be reused
            try renderer.releaseTexture(texture);
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

            return window;
        } else {
            i = i + 1;
            continue;
        }
    }

    return error.WindowsExhausted;
}

const BufferedState = struct {
    sync: bool = false,

    siblings: Link,

    x: i32 = 0,
    y: i32 = 0,
    scale: i32 = 1,

    input_region_id: ?u32,
    opaque_region_id: ?u32,

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

        self.input_region_id = null;
        self.opaque_region_id = null;

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

    pub fn deinit(self: *Link) void {
        if (self.next) |n| {
            n.top_link.prev = self.prev;
        }

        if(self.prev) |p| {
            p.top_link.next = self.next;
        }

        self.prev = null;
        self.next = null;
    }
};