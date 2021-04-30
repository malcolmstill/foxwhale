pub const CompositorOutput = backends.BackendOutput(Output);
pub var OUTPUTS: Stalloc(void, CompositorOutput, 16) = undefined;
pub const OUTPUT_BASE: usize = 1000;

pub const Output = struct {
    views: [4]View,

    const Self = @This();

    pub fn deinit(self: *Self) !void {
        var parent = @fieldParentPtr(CompositorOutput, "data", self);
        var freed_index = OUTPUTS.deinit(parent);

        // Inform all clients that have bound this output
        // that it is going away
        var client_it = clients.CLIENTS.iterator();
        while (client_it.next()) |client| {
            var obj_it = client.context.objects.iterator();
            while (obj_it.next()) |wl_object_entry| {
                var wl_object = wl_object_entry.value;
                if (@ptrToInt(self) == wl_object.container) {
                    // TODO: in release mode do not error
                    const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
                    const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;

                    try prot.wl_registry_send_global_remove(wl_registry.*, @intCast(u32, OUTPUT_BASE + freed_index));
                    std.debug.warn("OUTPUTS[{}] removed from CLIENTS[{}] (wl_output@{})\n", .{ freed_index, client.getIndexOf(), wl_object.id });
                }
            }
        }
    }

    pub fn getIndexOf(self: *Self) usize {
        return OUTPUTS.getIndexOf(self);
    }
};

pub fn newOutput(backend: *CompositorBackend, width: i32, height: i32) !*CompositorOutput {
    var output: *CompositorOutput = try OUTPUTS.new(undefined);
    output.* = try backend.newOutput(width, height);
    for (output.data.views) |*view| {
        view.* = views.makeView(output);
    }

    var it = clients.CLIENTS.iterator();
    while (it.next()) |client| {
        // TODO: in release mode do not error
        const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
        const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;
        const global_id = @intCast(u32, OUTPUTS.getIndexOf(output) + OUTPUT_BASE);
        try prot.wl_registry_send_global(wl_registry.*, global_id, "wl_output\x00", 2);
    }

    return output;
}

const std = @import("std");
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const views = @import("view.zig");
const backends = @import("backend/backend.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const View = @import("view.zig").View;
const CompositorBackend = @import("backend/backend.zig").Backend(Output);
