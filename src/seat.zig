pub var SEATS: Stalloc(void, Seat, 16) = undefined;

pub const Seat = struct {
    name: u32 = 0,

    const Self = @This();
};

const std = @import("std");
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
