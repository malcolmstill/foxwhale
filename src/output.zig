pub const CompositorOutput = backends.BackendOutput(Output);
// pub var OUTPUTS: Stalloc(void, CompositorOutput, 16) = undefined;
var OUTPUT_BASE: u32 = 1000;
const Compositor = @import("compositor.zig").Compositor;

pub const Output = struct {
    compositor: *Compositor,
    views: [4]View,
    id: u32,

    const Self = @This();

    pub fn init(compositor: *Compositor, alloc: *mem.Allocator, width: i32, height: i32) !*Self {
        const output = try allocator.create(Self);
        output.compositor = compositor;

        output.* = try backend.newOutput(width, height);
        for (output.data.views) |*view| {
            view.* = views.makeView(output);
        }

        output.id = OUTPUT_BASE;
        OUTPUT_BASE += 1;

        // var it = compositor.clientsclients.CLIENTS.iterator();
        for (compositor.clients.items) |client| {
            // TODO: in release mode do not error
            const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
            const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;
            try prot.wl_registry_send_global(wl_registry, output.id, "wl_output\x00", 2);
        }

        return output;
    }

    pub fn deinit(self: *Self) !void {
        var parent = @fieldParentPtr(CompositorOutput, "data", self);
        // var freed_index = OUTPUTS.deinit(parent);

        // Inform all clients that have bound this output
        // that it is going away
        // var client_it = clients.CLIENTS.iterator();
        for (self.compositor.clients.items) |client| {
            var obj_it = client.context.objects.iterator();
            while (obj_it.next()) |wl_object_entry| {
                var wl_object = wl_object_entry.value_ptr;
                if (@ptrToInt(self) == wl_object.container) {
                    // TODO: in release mode do not error
                    const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
                    const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;

                    try prot.wl_registry_send_global_remove(wl_registry, self.id);
                    // std.debug.warn("OUTPUTS[{}] removed from CLIENTS[{}] (wl_output@{})\n", .{ freed_index, client.getFd(), wl_object.id });
                }
            }
        }
    }

    pub fn getIndexOf(self: *Self) usize {
        return OUTPUTS.getIndexOf(self);
    }
};

// pub fn newOutput(compositor: *Compositor, backend: *CompositorBackend, width: i32, height: i32) !*CompositorOutput {
//     var output: *CompositorOutput = try OUTPUTS.new(undefined);
//     output.* = try backend.newOutput(width, height);
//     for (output.data.views) |*view| {
//         view.* = views.makeView(output);
//     }

//     // var it = compositor.clientsclients.CLIENTS.iterator();
//     for (compositor.clients.items) |client| {
//         // TODO: in release mode do not error
//         const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
//         const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;
//         const global_id = @intCast(u32, OUTPUTS.getIndexOf(output) + OUTPUT_BASE);
//         try prot.wl_registry_send_global(wl_registry, global_id, "wl_output\x00", 2);
//     }

//     return output;
// }

const std = @import("std");
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const views = @import("view.zig");
const backends = @import("backend/backend.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const View = @import("view.zig").View;
const CompositorBackend = @import("backend/backend.zig").Backend(Output);
