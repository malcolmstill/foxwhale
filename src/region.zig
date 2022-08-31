const std = @import("std");
const renderer = @import("renderer.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const Client = @import("client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const Window = @import("window.zig").Window;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const RectangleBuffer = LinearFifo(RectangleOp, LinearFifoBufferType{ .Static = 64 });

pub var REGIONS: Stalloc(Client, Region, 1024) = undefined;

pub const Region = struct {
    wl_region_id: u32,
    rectangles: RectangleBuffer,
    window: ?*Window,

    const Self = @This();

    pub fn pointInside(self: *Self, local_x: f64, local_y: f64) bool {
        var slice = self.rectangles.readableSlice(0);
        for (slice) |rect| {
            const left = @intToFloat(f64, rect.rectangle.x);
            const right = left + @intToFloat(f64, rect.rectangle.width);
            const top = @intToFloat(f64, rect.rectangle.y);
            const bottom = top + @intToFloat(f64, rect.rectangle.height);

            if (local_x >= left and local_x <= right) {
                if (local_y >= top and local_y <= bottom) {
                    return (if (rect.op == .Add) true else false);
                }
            }
        }

        return false;
    }

    pub fn deinit(self: *Self) !void {
        self.rectangles = RectangleBuffer.init();
        _ = REGIONS.deinit(self);
        self.window = null;
        // std.debug.warn("released region {}\n", .{freed_index});
    }
};

pub fn newRegion(client: *Client, wl_region_id: u32) !*Region {
    const region: *Region = try REGIONS.new(client);
    region.wl_region_id = wl_region_id;
    return region;
}

pub fn releaseRegions(client: *Client) !void {
    try REGIONS.releaseBelongingTo(client);
}

pub const RegionOp = enum {
    Add,
    Subtract,
};

pub const RectangleOp = struct {
    rectangle: Rectangle,
    op: RegionOp,
};
