const std = @import("std");
const Server = @import("server.zig").Server;
const Client = @import("client.zig").Client;
const Backend = @import("backend/backend.zig").Backend;
const WlMessage = @import("protocols.zig").WlMessage;

pub const Subsystem = enum {
    server,
    client,
    backend,
};

pub const Event = union(Subsystem) {
    server: ServerTargetEvent,
    client: ClientTargetEvent,
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

pub const ServerTargetEvent = struct {
    server: *Server,
    event: ServerEvent,
};

pub const ServerEventType = enum {
    client_connected,
};

pub const ServerEvent = union(ServerEventType) {
    client_connected: std.net.StreamServer.Connection,
};

pub const ClientTargetEvent = struct {
    client: *Client,
    event: ClientEvent,
};

pub const ClientEventType = enum {
    hangup,
    err,
    message,
};

pub const ClientEvent = union(ClientEventType) {
    hangup: i32,
    err: i32,
    message: WlMessage,
};
