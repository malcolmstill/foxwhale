const std = @import("std");
const mem = std.mem;
const views = @import("../view.zig");
const backends = @import("../backend/backend.zig");
const View = @import("../view.zig").View;
const Backend = @import("../backend/backend.zig").Backend;
const BackendOutput = @import("../backend/backend.zig").BackendOutput;
const Server = @import("../server.zig").Server;

pub const Output = struct {
    server: *Server,
    views: [4]View,
    id: u32,
    backend: BackendOutput,

    const Self = @This();

    pub fn init(server: *Server, backend: *Backend, alloc: mem.Allocator, width: i32, height: i32) !*Self {
        const output = try alloc.create(Self);
        output.server = server;

        output.backend = try backend.newOutput(width, height);
        for (output.views) |*view| {
            view.* = views.makeView(output);
        }

        output.id = server.output_base;
        server.output_base += 1;

        var it = server.clients.iterator();
        while (it.next()) |client| {
            const wl_registry = client.wl_registry orelse continue;
            try wl_registry.sendGlobal(output.id, "wl_output\x00", 2);
        }

        return output;
    }

    pub fn deinit(self: *Self) !void {
        var it = server.clients.iterator();
        while (it.next()) |client| {
            var obj_it = client.objects.iterator();
            while (obj_it.next()) |ro| {
                var output = switch (ro.resource) {
                    .output => |o| o,
                    else => continue,
                };
                if (self == output) {
                    const wl_registry = client.wl_registry orelse continue;
                    try wl_registry.sendGlobalRemove(self.id);
                }
            }
        }
    }
};
