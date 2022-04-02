const std = @import("std");
const mem = std.mem;
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const views = @import("view.zig");
const backends = @import("backend/backend.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const View = @import("view.zig").View;
const Backend = @import("backend/backend.zig").Backend;
const BackendOutput = @import("backend/backend.zig").BackendOutput;
pub var OUTPUT_BASE: u32 = 1000;
const Compositor = @import("compositor.zig").Compositor;

pub const Output = struct {
    compositor: *Compositor,
    views: [4]View,
    id: u32,
    backend: BackendOutput,

    const Self = @This();

    pub fn init(compositor: *Compositor, backend: *Backend, alloc: *mem.Allocator, width: i32, height: i32) !*Self {
        const output = try alloc.create(Self);
        output.compositor = compositor;

        output.backend = try backend.newOutput(width, height);
        for (output.views) |*view| {
            view.* = views.makeView(output);
        }

        output.id = OUTPUT_BASE;
        OUTPUT_BASE += 1;

        for (compositor.clients.items) |client| {
            // TODO: in release mode do not error
            const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
            const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;
            try prot.wl_registry_send_global(wl_registry, output.id, "wl_output\x00", 2);
        }

        return output;
    }

    pub fn deinit(self: *Self) !void {
        for (self.compositor.clients.items) |client| {
            var obj_it = client.context.objects.iterator();
            while (obj_it.next()) |wl_object_entry| {
                var wl_object = wl_object_entry.value_ptr;
                if (@ptrToInt(self) == wl_object.container) {
                    // TODO: in release mode do not error
                    const wl_registry_id = client.wl_registry_id orelse return error.ClientHasNoRegistry;
                    const wl_registry = client.context.get(wl_registry_id) orelse return error.ContextHasNoRegistry;

                    try prot.wl_registry_send_global_remove(wl_registry, self.id);
                }
            }
        }
    }

    pub fn getIndexOf(self: *Self) usize {
        return OUTPUTS.getIndexOf(self);
    }
};
