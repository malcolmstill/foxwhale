const std = @import("std");
const views = @import("../view.zig");
const View = @import("../view.zig").View;
const BackendOutput = @import("foxwhale-backend").BackendOutput;
const Server = @import("../server.zig").Server;

pub const Output = struct {
    server: *Server,
    views: [4]View,
    backend_output: *BackendOutput,
    id: u32,

    pub fn init(server: *Server, backend_output: *BackendOutput) !Output {
        defer server.output_base += 1;
        const id = server.output_base;

        var it = server.clients.iterator();
        while (it.next()) |client| {
            const wl_registry = client.wl_registry orelse continue;
            try wl_registry.sendGlobal(id, "wl_output\x00", 2);
        }

        return Output{
            .server = server,
            .backend_output = backend_output,
            .id = id,
            .views = [_]View{
                View.init(backend_output),
                View.init(backend_output),
                View.init(backend_output),
                View.init(backend_output),
            },
        };
    }

    pub fn getWidth(self: *Output) i32 {
        return self.backend_output.getWidth();
    }

    pub fn getHeight(self: *Output) i32 {
        return self.backend_output.getHeight();
    }

    pub fn deinit(self: *Output) !void {
        var it = self.server.clients.iterator();
        while (it.next()) |client| {
            const wl_registry = client.wl_registry orelse continue;

            var obj_it = client.objects.iterator();
            while (obj_it.next()) |ro| {
                const output = switch (ro.resource) {
                    .output => |o| o,
                    else => continue,
                };
                if (self != output) continue;

                try wl_registry.sendGlobalRemove(self.id);
            }
        }
    }
};
