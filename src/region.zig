const std = @import("std");
const renderer = @import("renderer.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const RectangleBuffer = LinearFifo(RectangleOp, LinearFifoBufferType{ .Static = 64 });

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

    pub fn current(self: *Self) *BufferedState {
        return &self.state[self.stateIndex];
    }

    pub fn pending(self: *Self) *BufferedState {
        return &self.state[self.stateIndex +% 1];
    }

    pub fn deinit(self: *Self) !void {
        self.current().rectangles = RectangleBuffer.init();
        self.pending().rectangles = RectangleBuffer.init();
        var freed_index = REGIONS.deinit(self);
        std.debug.warn("released region {}\n", .{freed_index});
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
    rectangles: RectangleBuffer,
};

pub const RegionOp = enum {
    Add,
    Subtract,
};

pub const RectangleOp = struct {
    rectangle: Rectangle,
    op: RegionOp,
};