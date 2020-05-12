const std = @import("std");
const clients = @import("client.zig");
const prot = @import("protocols.zig");
const Stalloc = @import("stalloc.zig").Stalloc;
const Backend = @import("backend/backend.zig").Backend;
const BackendType = @import("backend/backend.zig").BackendType;
const HeadlessOutput = @import("backend/headless.zig").HeadlessOutput;
const GLFWOutput = @import("backend/glfw.zig").GLFWOutput;

pub var OUTPUTS: Stalloc(void, Output, 16) = undefined;
pub const OUTPUT_BASE: usize = 1000;

pub const Output = union(BackendType) {
    Headless: HeadlessOutput,
    GLFW: GLFWOutput,

    const Self = @This();

    pub fn begin(self: Self) void {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.begin(),
            BackendType.GLFW => |glfw_output| glfw_output.begin(),
        };
    }

    pub fn end(self: Self) void {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.end(),
            BackendType.GLFW => |glfw_output| glfw_output.end(),
        };
    }

    pub fn swap(self: Self) void {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.swap(),
            BackendType.GLFW => |glfw_output| glfw_output.swap(),
        };
    }

    pub fn shouldClose(self: Self) bool {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.shouldClose(),
            BackendType.GLFW => |glfw_output| glfw_output.shouldClose(),
        };
    }

    pub fn getWidth(self: Self) i32 {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.getWidth(),
            BackendType.GLFW => |glfw_output| glfw_output.getWidth(),
        };
    }

    pub fn getHeight(self: Self) i32 {
        return switch (self) {
            BackendType.Headless => |headless_output| headless_output.getHeight(),
            BackendType.GLFW => |glfw_output| glfw_output.getHeight(),
        };
    }

    pub fn deinit(self: *Self) !void {
        var freed_index = OUTPUTS.deinit(self);

        // Inform all clients that have bound this output
        // that it is going away
        var client_it = clients.CLIENTS.iterator();
        while(client_it.next()) |client| {
            var obj_it = client.context.objects.iterator();
            while(obj_it.next()) |wl_object_entry| {
                var wl_object = wl_object_entry.value;
                if (@ptrToInt(self) == wl_object.container) {
                    if (client.wl_registry_id) |wl_registry_id| {
                        // TODO: in release mode do not error
                        if (client.context.get(wl_registry_id)) |wl_registry| {
                            try prot.wl_registry_send_global_remove(wl_registry.*, @intCast(u32, OUTPUT_BASE + freed_index));
                            std.debug.warn("OUTPUTS[{}] removed from CLIENTS[{}] (wl_output@{})\n", .{freed_index, client.getIndexOf(), wl_object.id});
                        } else {
                            return error.ContextHasNoRegistry;
                        }
                    } else {
                        return error.ClientHasNoRegistry;
                    }
                }
            }
        }

        return switch (self.*) {
            BackendType.Headless => |*headless_output| headless_output.deinit(),
            BackendType.GLFW => |*glfw_output| glfw_output.deinit(),
            else => return,
        };
    }

    pub fn getIndexOf(self: *Self) usize {
        return OUTPUTS.getIndexOf(self);
    }
};

pub fn newOutput(backend: *Backend, width: i32, height: i32) !*Output {
    var output = try OUTPUTS.new(undefined);
    output.* = try backend.newOutput(width, height);

    var it = clients.CLIENTS.iterator();
    while(it.next()) |client| {
        if (client.wl_registry_id) |wl_registry_id| {
            if (client.context.get(wl_registry_id)) |wl_registry| {
                var global_id = @intCast(u32, OUTPUTS.getIndexOf(output) + OUTPUT_BASE);
                try prot.wl_registry_send_global(wl_registry.*, global_id, "wl_output\x00", 2);
            } else {
                return error.ContextHasNoRegistry;
            }
        }
    }

    return output;
}