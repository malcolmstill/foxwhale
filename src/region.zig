const std = @import("std");
const renderer = @import("renderer.zig");
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;

const MAX_REGIONS = 1024;
pub var REGIONS: [MAX_REGIONS]Region = undefined;

pub const Region = struct {
    index: usize = 0,
    in_use: bool = false,
    client: *Client,

    wl_region_id: u32,

    state: [2]BufferedState = undefined,
    stateIndex: u1 = 0,

    const Self = @This();

    // flip double-buffered state
    pub fn flip(self: *Self) void {
        self.stateIndex +%= 1;
    }

    pub fn pending(self: *Self) *BufferedState {
        return &self.state[self.stateIndex +% 1];
    }

    pub fn deinit(self: *Self) !void {
        std.debug.warn("release region\n", .{});
        self.in_use = false;
    }
};

pub fn newRegion(client: *Client, wl_region_id: u32) !*Region {
    var i: usize = 0;
    while (i < MAX_REGIONS) {
        var region: *Region = &REGIONS[i];
        if (region.in_use == false) {
            region.index = i;
            region.in_use = true;
            region.client = client;

            region.wl_region_id = wl_region_id;

            return region;
        } else {
            i = i + 1;
            continue;
        }
    }

    return error.RegionsExhausted;
}

const BufferedState = struct {
    rectangles: LinearFifo(RectangleOp, LinearFifoBufferType{ .Static = 64 }),
};

pub const RegionOp = enum {
    Add,
    Subtract,
};

pub const RectangleOp = struct {
    rectangle: Rectangle,
    op: RegionOp,
};

pub fn releaseRegions(client: *Client) !void {
    var i: usize = 0;
    while (i < MAX_REGIONS) {
        var region: *Region = &REGIONS[i];
        if (region.in_use and region.client == client) {
            try region.deinit();
        }
        i = i + 1;
    }
}