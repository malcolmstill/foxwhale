const std = @import("std");
const headless = @import("headless.zig");
const glfw = @import("glfw.zig");
const view = @import("../view.zig");
const HeadlessBackend = @import("headless.zig").HeadlessBackend;
const GLFWBackend = @import("glfw.zig").GLFWBackend;
const Output = @import("../output.zig").Output;
const OutputBackend = @import("../output.zig").OutputBackend;
const View = @import("../view.zig").View;

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
            BackendType.Headless => |headless_backend| -1,
            BackendType.GLFW => |glfw_backend| 10,
        };
    }

    pub fn name(self: Backend) []const u8 {
        return switch (self) {
            BackendType.Headless => "Headless",
            BackendType.GLFW => "GLFW",
        };
    }

    pub fn newOutput(self: *Backend, w: i32, h: i32) !Output {
        var output_backend = switch (self.*) {
            BackendType.Headless => |*headless_backend| OutputBackend{ .Headless = try headless_backend.newOutput(w, h) },
            BackendType.GLFW => |*glfw_backend| OutputBackend{ .GLFW = try glfw_backend.newOutput(w, h) },
        };

        return Output{
            .backend = output_backend,
            .views = [_]View{view.makeView()} ** 4,
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