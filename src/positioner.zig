const std = @import("std");
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const Rectangle = @import("rectangle.zig").Rectangle;
const Stalloc = @import("stalloc.zig").Stalloc;
const Client = @import("client.zig").Client;

pub var POSITIONERS: Stalloc(Client, Positioner, 512) = undefined;

pub const Positioner = struct {
    client: *Client,
    xdg_positioner_id: u32,
    width: i32,
    height: i32,
    anchor_rect: Rectangle,
    anchor: prot.xdg_positioner_anchor,
    gravity: prot.xdg_positioner_gravity,
    constraint_adjustment: prot.xdg_positioner_constraint_adjustment,
    x: i32,
    y: i32,

    const Self = @This();

    pub fn deinit(self: *Self) !void {
        var freed_index = POSITIONERS.deinit(self);
        self.xdg_positioner_id = 0;
        self.width = 0;
        self.height = 0;
        self.x = 0;
        self.y = 0;
        self.anchor_rect.x = 0;
        self.anchor_rect.y = 0;
        self.anchor_rect.width = 0;
        self.anchor_rect.height = 0;
        self.anchor = .none;
        self.gravity = .none;
        std.log.warn("Freed positioner: {}\n", .{freed_index});
    }
};

pub fn newPositioner(client: *Client, xdg_positioner_id: u32) !*Positioner {
    var positioner = try POSITIONERS.new(client);
    positioner.xdg_positioner_id = xdg_positioner_id;

    return positioner;
}

pub fn releasePositioners(client: *Client) !void {
    try POSITIONERS.releaseBelongingTo(client);
}
