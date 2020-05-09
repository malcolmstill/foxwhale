const std = @import("std");
const renderer = @import("renderer.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;

pub var REGIONS: Stalloc(Client, Region, 1024) = undefined;

pub const Region = struct {
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
    }
};

pub fn newRegion(client: *Client, wl_region_id: u32) !*Region {
    var region: *Region = try REGIONS.new(client);
    region.wl_region_id = wl_region_id;
    return region;
}

pub fn releaseRegions(client: *Client) !void {
    try REGIONS.releaseBelongingTo(client);
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