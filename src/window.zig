const std = @import("std");
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

    pub fn render(self: *Self) !void {
        if (self.texture) |texture| {
            renderer.setGeometry(self);
            try renderer.renderSurface(renderer.PROGRAM, texture);
        }
    }

    // ToplevelIterator provides an iterator for moving
    // between toplevel windows (if the window happens to
    // be toplevel)
    pub const ToplevelIterator = struct {
        current: ?*Window,

        pub fn next(self: *ToplevelIterator) ?*Window {
            if (self.current) |window| {
                self.current = window.top_link.next;
                return window;
            }

            return null;
        }

        pub fn prev(self: *ToplevelIterator) ?*Window {
            if (self.current) |window| {
                self.current = window.top_link.prev;
                return window;
            }

            return null;
        }
    };

    pub fn toplevelIterator(self: *Self) ToplevelIterator {
        return ToplevelIterator {
            .current = self,
        };
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

    prev: ?*Window,
    next: ?*Window,

    x: i32 = 0,
    y: i32 = 0,
    scale: i32 = 1,

    input_region_id: ?u32,
    opaque_region_id: ?u32,

    min_width: ?i32,
    min_height: ?i32,
    max_width: ?i32,
    max_height: ?i32,

    const Self = @This();

    fn deinit(self: *Self) void {
        self.sync = false;

        self.prev = null;
        self.next = null;

        self.x = 0;
        self.y = 0;
        self.scale = 1;

        self.input_region_id = null;
        self.opaque_region_id = null;

        self.min_width = null;
        self.min_height = null;
        self.max_width = null;
        self.max_height = null;
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