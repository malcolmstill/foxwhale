const std = @import("std");
const Client = @import("client.zig").Client;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;

const MAX_WINDOWS = 512;
pub var WINDOWS: [MAX_WINDOWS]Window = undefined;

pub const Window = struct {
    index: usize = 0,
    in_use: bool = false,

    texture: ?u32,
    width: i32,
    height: i32,

    state: [2]BufferedState = undefined,
    stateIndex: u1 = 0,
    wl_surface_id: u32,
    wl_buffer_id: ?u32,
    xdg_surface_id: ?u32,
    xdg_toplevel_id: ?u32,
    client: *Client,
    geometry: [24]f32 = undefined,
    title: [128]u8 = undefined,
    callbacks: LinearFifo(u32, LinearFifoBufferType{ .Static = 32 }),

    const Self = @This();

    // flip double-buffered state
    pub fn flip(self: *Self) void {
        self.stateIndex +%= 1;
    }

    pub fn pending(self: *Self) *BufferedState {
        return &self.state[self.stateIndex +% 1];
    }

    pub fn deinit(self: *Self) void {
        std.debug.warn("release window\n", .{});
        self.in_use = false;
        self.wl_buffer_id = null;
        self.xdg_surface_id = null;
        self.xdg_toplevel_id = null;
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

            return window;
        } else {
            i = i + 1;
            continue;
        }
    }

    return WindowsError.WindowsExhausted;
}

const BufferedState = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

const WindowsError = error {
    WindowsExhausted,
};

pub fn releaseWindows(client: *Client) void {
    var i: usize = 0;
    while (i < MAX_WINDOWS) {
        var window: *Window = &WINDOWS[i];
        if (window.in_use and window.client == client) {
            window.deinit();
        }
        i = i + 1;
    }
}