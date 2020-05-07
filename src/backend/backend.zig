const std = @import("std");
const headless = @import("headless.zig");
const glfw = @import("glfw.zig");
const HeadlessBackend = @import("headless.zig").HeadlessBackend;
const GLFWBackend = @import("glfw.zig").GLFWBackend;

pub const BackendType = enum {
    Headless,
    GLFW,
};

pub fn init(backend_type: BackendType) !Backend {
    return switch (backend_type) {
        BackendType.Headless => Backend { .Headless = try headless.init() },
        BackendType.GLFW => Backend { .GLFW = try glfw.init() },
    };
}

pub const Backend = union(BackendType) {
    Headless: HeadlessBackend,
    GLFW: GLFWBackend,

    pub fn draw(self: Backend) void {
        return switch (self) {
            BackendType.Headless => |headless_backend| headless_backend.draw(),
            BackendType.GLFW => |glfw_backend| glfw_backend.draw(),
        };
    }

    pub fn wait(self: Backend) i32 {
        return switch (self) {
            BackendType.Headless => |headless_backend| headless_backend.wait(),
            BackendType.GLFW => |glfw_backend| glfw_backend.wait(),
        };
    }

    pub fn shouldClose(self: Backend) bool {
        return switch (self) {
            BackendType.Headless => |headless_backend| headless_backend.shouldClose(),
            BackendType.GLFW => |glfw_backend| glfw_backend.shouldClose(),
        };
    }

    pub fn deinit(self: Backend) void {
        return switch (self) {
            BackendType.Headless => |headless_backend| headless_backend.deinit(),
            BackendType.GLFW => |glfw_backend| glfw_backend.deinit(),
        };
    }
};

pub fn detect() BackendType {
    if (std.os.getenv("DISPLAY")) |display| {
        return BackendType.GLFW;
    }

    return BackendType.Headless;
}