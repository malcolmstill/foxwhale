const std = @import("std");
const headless = @import("headless.zig");
const glfw = @import("glfw.zig");
const HeadlessBackend = @import("headless.zig").HeadlessBackend;
const GLFWBackend = @import("glfw.zig").GLFWBackend;
const HeadlessOutput = @import("headless.zig").HeadlessOutput;
const GLFWOutput = @import("glfw.zig").GLFWOutput;

pub const BackendType = enum {
    Headless,
    GLFW,
};

pub const OutputBackend = union(BackendType) {
    Headless: HeadlessOutput,
    GLFW: GLFWOutput,
};

pub fn BackendOutput(comptime T: type) type {
    return struct {
        backend: OutputBackend,
        data: T,

        const Self = @This();

        pub fn begin(self: Self) !void {
            switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.begin(),
                BackendType.GLFW => |glfw_output| glfw_output.begin(),
            }
        }

        pub fn end(self: Self) void {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.end(),
                BackendType.GLFW => |glfw_output| glfw_output.end(),
            };
        }

        pub fn swap(self: Self) void {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.swap(),
                BackendType.GLFW => |glfw_output| glfw_output.swap(),
            };
        }

        pub fn getWidth(self: Self) i32 {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.getWidth(),
                BackendType.GLFW => |glfw_output| glfw_output.getWidth(),
            };
        }

        pub fn getHeight(self: Self) i32 {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.getHeight(),
                BackendType.GLFW => |glfw_output| glfw_output.getHeight(),
            };
        }

        pub fn shouldClose(self: Self) bool {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.shouldClose(),
                BackendType.GLFW => |glfw_output| glfw_output.shouldClose(),
            };
        }

        pub fn deinit(self: *Self) !void {
            try self.data.deinit();

            return switch (self.backend) {
                BackendType.Headless => |*headless_output| headless_output.deinit(),
                BackendType.GLFW => |*glfw_output| glfw_output.deinit(),
                else => return,
            };
        }
    };
}

pub fn Backend(comptime T: type) type {
    return union(BackendType) {
        Headless: HeadlessBackend,
        GLFW: GLFWBackend,

        const Self = @This();

        pub fn init(backend_type: BackendType) !Self {
            return switch (backend_type) {
                BackendType.Headless => Self { .Headless = try headless.init() },
                BackendType.GLFW => Self { .GLFW = try glfw.init() },
            };
        }

        pub fn wait(self: Self) i32 {
            return switch (self) {
                BackendType.Headless => |headless_backend| -1,
                BackendType.GLFW => |glfw_backend| 10,
            };
        }

        pub fn name(self: Self) []const u8 {
            return switch (self) {
                BackendType.Headless => "Headless",
                BackendType.GLFW => "GLFW",
            };
        }

        pub fn newOutput(self: *Backend(T), w: i32, h: i32) !BackendOutput(T) {
            var output_backend = switch (self.*) {
                BackendType.Headless => |*headless_backend| OutputBackend{ .Headless = try headless_backend.newOutput(w, h) },
                BackendType.GLFW => |*glfw_backend| OutputBackend{ .GLFW = try glfw_backend.newOutput(w, h) },
            };

            return BackendOutput(T){
                .backend = output_backend,
                .data = undefined,
            };
        }

        pub fn deinit(self: Self) void {
            return switch (self) {
                BackendType.Headless => |headless_backend| headless_backend.deinit(),
                BackendType.GLFW => |glfw_backend| glfw_backend.deinit(),
            };
        }
    };
}

pub fn detect() BackendType {
    if (std.os.getenv("DISPLAY")) |display| {
        return BackendType.GLFW;
    }

    return BackendType.Headless;
}