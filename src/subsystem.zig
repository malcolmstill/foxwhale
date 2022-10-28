const std = @import("std");
const Server = @import("server.zig").Server;
const Client = @import("client.zig").Client;
const Backend = @import("backend/backend.zig").Backend;

pub const Subsystem = enum {
    server,
    client,
    backend,
};

pub const Event = union(Subsystem) {
    server: Server.TargetEvent,
    client: Client.TargetEvent,
    backend: Backend.TargetEvent,
};

pub const Target = union(Subsystem) {
    server: *Server,
    client: *Client,
    backend: *Backend,

    pub fn iterator(self: Target) SubsystemIterator {
        return switch (self) {
            // inline else => |target| return try target.dispatch(event_type),
            .server => |target| target.iterator(),
            .client => |target| target.iterator(),
            .backend => |target| Backend.Iterator.init(target),
        };
    }
};

pub const SubsystemIterator = union(Subsystem) {
    server: Server.Iterator,
    client: Client.Iterator,
    backend: Backend.Iterator,

    pub fn next(self: *SubsystemIterator, events: u32) !?Event {
        return switch (self.*) {
            .server => |*s| try s.next(events),
            .client => |*c| try c.next(events),
            .backend => |*b| try b.next(events),
        };
    }
};
