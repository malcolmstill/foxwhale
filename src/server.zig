const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const Event = @import("subsystem.zig").Event;
const SubsystemIterator = @import("subsystem.zig").SubsystemIterator;
const Client = @import("client.zig").Client;
const Context = @import("wl/context.zig").Context;
const WlObject = @import("protocols.zig").WlObject;
const WlDisplay = @import("protocols.zig").WlDisplay;
const WlSurface = @import("protocols.zig").WlSurface;
const WlRegion = @import("protocols.zig").WlRegion;
const StaticArray = @import("stalloc.zig").StaticArray;
const Window = @import("window.zig").Window;
const Buffer = @import("buffer.zig").Buffer;
const Region = @import("region.zig").Region;
const ShmPool = @import("shm_pool.zig").ShmPool;

pub const Server = struct {
    alloc: mem.Allocator,
    server: std.net.StreamServer,
    clients: std.TailQueue(Client),
    // resources:
    windows: List(Window),
    regions: List(Region),
    buffers: List(Buffer),
    shm_pools: List(ShmPool),

    const ClientNode = std.TailQueue(Client).Node;
    const Self = @This();

    pub const TargetEvent = struct {
        server: *Server,
        event: ServerEvent,
    };

    pub const EventType = enum {
        client_connected,
    };

    pub const ServerEvent = union(EventType) {
        client_connected: std.net.StreamServer.Connection,
    };

    pub fn init(alloc: mem.Allocator) !Server {
        return Server{
            .alloc = alloc,
            .server = try socket(),
            .clients = std.TailQueue(Client){},
            .windows = List(Window).init(alloc),
            .regions = List(Region).init(alloc),
            .buffers = List(Buffer).init(alloc),
            .shm_pools = List(ShmPool).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        while (self.clients.pop()) |node| {
            self.alloc.destroy(node);
        }

        self.windows.deinit();
        self.regions.deinit();
        self.buffers.deinit();
        self.shm_pools.deinit();

        self.server.close();
    }

    pub fn addClient(self: *Self, conn: std.net.StreamServer.Connection) !*Client {
        const node = try self.alloc.create(ClientNode);
        const client: *Client = &node.data;
        const wl_display = WlDisplay.init(1, &client.context, 0);

        client.* = Client.init(self.alloc, self, conn, wl_display);

        try client.context.register(WlObject{ .wl_display = wl_display });

        self.clients.append(node);

        return client;
    }

    pub fn removeClient(self: *Self, client: *Client) void {
        const node: *ClientNode = @fieldParentPtr(ClientNode, "data", client);
        self.clients.remove(node);
        self.alloc.destroy(node);
    }

    pub fn iterator(self: *Server) SubsystemIterator {
        return SubsystemIterator{ .server = Iterator.init(self) };
    }

    pub const Iterator = struct {
        server: *Server,
        accepted: bool = false,

        pub fn init(server: *Server) Iterator {
            return Iterator{
                .server = server,
            };
        }

        pub fn next(self: *Iterator, _: u32) !?Event {
            if (self.accepted) return null;

            var conn = try self.server.server.accept();

            self.accepted = true;

            return Event{
                .server = Server.TargetEvent{
                    .server = self.server,
                    .event = ServerEvent{
                        .client_connected = conn,
                    },
                },
            };
        }
    };
};

fn socket() !std.net.StreamServer {
    _ = std.os.unlink("/run/user/1000/wayland-1") catch {};
    var addr = try std.net.Address.initUnix("/run/user/1000/wayland-1");

    var server = std.net.StreamServer.init(.{});
    try server.listen(addr);

    return server;
}

fn List(comptime T: type) type {
    return struct {
        alloc: mem.Allocator,
        resources: std.TailQueue(T),

        const Self = @This();

        const Node = std.TailQueue(T).Node;

        pub fn init(alloc: mem.Allocator) Self {
            return Self{
                .alloc = alloc,
                .resources = std.TailQueue(T){},
            };
        }

        pub fn add(self: *Self, resource: T) !*T {
            const node = try self.alloc.create(Node);
            var resource_ptr: *T = &node.data;

            resource_ptr.* = resource;

            self.resources.append(node);

            return resource_ptr;
        }

        pub fn remove(self: *Self, resource_ptr: *T) void {
            const node: *Node = @fieldParentPtr(Node, "data", resource_ptr);
            self.resources.remove(node);
            self.alloc.destroy(node);
        }

        pub fn deinit(self: *Self) void {
            while (self.resources.pop()) |node| {
                self.alloc.destroy(node);
            }
        }
    };
}
