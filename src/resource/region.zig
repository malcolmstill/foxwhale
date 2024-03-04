const std = @import("std");
const Client = @import("../client.zig").Client;
const Rectangle = @import("rectangle.zig").Rectangle;
const Window = @import("window.zig").Window;
const LinearFifo = std.fifo.LinearFifo;
const LinearFifoBufferType = std.fifo.LinearFifoBufferType;
const RectangleBuffer = LinearFifo(RectangleOp, LinearFifoBufferType{ .Static = 64 });

const wl = @import("../client.zig").wl;

pub const Region = struct {
    client: *Client,
    wl_region: wl.WlRegion,
    rectangles: RectangleBuffer,
    window: ?*Window,

    const Self = @This();

    pub fn init(client: *Client, wl_region: wl.WlRegion) Region {
        return .{
            .client = client,
            .wl_region = wl_region,
            .rectangles = RectangleBuffer.init(),
            .window = null,
        };
    }

    pub fn pointInside(region: *Region, local_x: f64, local_y: f64) bool {
        const slice = region.rectangles.readableSlice(0);
        for (slice) |rect| {
            const left: f64 = @floatFromInt(rect.rectangle.x);
            const right = left + @as(f64, @floatFromInt(rect.rectangle.width));
            const top: f64 = @floatFromInt(rect.rectangle.y);
            const bottom = top + @as(f64, @floatFromInt(rect.rectangle.height));

            if (local_x >= left and local_x <= right) {
                if (local_y >= top and local_y <= bottom) {
                    return (if (rect.op == .Add) true else false);
                }
            }
        }

        return false;
    }
};

pub const RegionOp = enum {
    Add,
    Subtract,
};

pub const RectangleOp = struct {
    rectangle: Rectangle,
    op: RegionOp,
};
