const std = @import("std");
const Server = @import("server.zig").Server;
const Client = @import("client.zig").Client;
const Backend = @import("foxwhale-backend").Backend;

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

    pub fn iterator(target: Target) SubsystemIterator {
        return switch (target) {
            // inline else => |target| return try target.dispatch(event_type),
            .server => |server| .{ .server = Server.Iterator.init(server) },
            .client => |client| .{ .client = Client.Iterator.init(client) },
            .backend => |backend| .{ .backend = Backend.Iterator.init(backend) },
        };
    }
};

pub const SubsystemIterator = union(Subsystem) {
    server: Server.Iterator,
    client: Client.Iterator,
    backend: Backend.Iterator,

    pub fn next(it: *SubsystemIterator, events: u32) !?Event {
        return switch (it.*) {
            .server => |*s| .{ .server = try s.next(events) orelse return null },
            .client => |*c| .{ .client = try c.next(events) orelse return null },
            .backend => |*b| .{ .backend = try b.next(events) orelse return null },
        };
    }
};
