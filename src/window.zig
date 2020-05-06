const std = @import("std");
const Client = @import("client.zig").Client;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;

const MAX_WINDOWS = 512;
var WINDOWS: [MAX_WINDOWS]Window = undefined;

pub const Window = struct {
    index: usize = 0,
    in_use: bool = false,
    state: [2]BufferedState = undefined,
    stateIndex: u1 = 0,
    wl_surface: u32,
    wl_buffer: ?u32,
    xdg_surface: ?u32,
    xdg_toplevel: ?u32,
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
        WINDOWS[self.index].in_use = false;
    }
};

pub fn newWindow(client: *Client, surface: u32) !*Window {
    var i: usize = 0;
    while (i < MAX_WINDOWS) {
        if (WINDOWS[i].in_use == false) {
            WINDOWS[i].index = i;
            WINDOWS[i].in_use = true;
            WINDOWS[i].client = client;
            WINDOWS[i].wl_surface = surface;

            return &WINDOWS[i];
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
        if (WINDOWS[i].client == client) {
            WINDOWS[i].deinit();
        }
        i = i + 1;
    }
}