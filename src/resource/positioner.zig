const std = @import("std");
const XdgPositioner = @import("../wl/protocols.zig").XdgPositioner;
const Rectangle = @import("rectangle.zig").Rectangle;
const Client = @import("../client.zig").Client;

pub const Positioner = struct {
    client: *Client,
    xdg_positioner: XdgPositioner,
    width: i32 = 0,
    height: i32 = 0,
    anchor_rect: Rectangle = Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 },
    anchor: XdgPositioner.Anchor = .none,
    gravity: XdgPositioner.Gravity = .none,
    constraint_adjustment: XdgPositioner.ConstraintAdjustment = .{},
    x: i32 = 0,
    y: i32 = 0,

    const Self = @This();

    pub fn init(client: *Client, xdg_positioner: XdgPositioner) Positioner {
        return Positioner{
            .client = client,
            .xdg_positioner = xdg_positioner,
        };
    }

    pub fn deinit(_: *Positioner) void {}
};
