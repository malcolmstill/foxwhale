const std = @import("std");
const headless = @import("headless.zig");
const glfw = @import("glfw.zig");
const drm = @import("drm.zig");
const HeadlessBackend = @import("headless.zig").HeadlessBackend;
const HeadlessOutput = @import("headless.zig").HeadlessOutput;
const GLFWBackend = @import("glfw.zig").GLFWBackend;
const GLFWOutput = @import("glfw.zig").GLFWOutput;
const DRMBackend = @import("drm.zig").DRMBackend;
const DRMOutput = @import("drm.zig").DRMOutput;

pub const BackendType = enum {
    Headless,
    GLFW,
    DRM,
};

pub const OutputBackend = union(BackendType) {
    Headless: HeadlessOutput,
    GLFW: GLFWOutput,
    DRM: DRMOutput,
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
                BackendType.DRM => |drm_output| drm_output.begin(),
            }
        }

        pub fn end(self: Self) void {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.end(),
                BackendType.GLFW => |glfw_output| glfw_output.end(),
                BackendType.DRM => |drm_output| drm_output.end(),
            };
        }

        pub fn swap(self: *Self) !void {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.swap(),
                BackendType.GLFW => |glfw_output| glfw_output.swap(),
                BackendType.DRM => |*drm_output| try drm_output.swap(),
            };
        }

        pub fn isPageFlipScheduled(self: *Self) bool {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| false,
                BackendType.GLFW => |glfw_output| false,
                BackendType.DRM => |drm_output| drm_output.isPageFlipScheduled(),
            };
        }

        pub fn getWidth(self: Self) i32 {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.getWidth(),
                BackendType.GLFW => |glfw_output| glfw_output.getWidth(),
                BackendType.DRM => |drm_output| drm_output.getWidth(),
            };
        }

        pub fn getHeight(self: Self) i32 {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.getHeight(),
                BackendType.GLFW => |glfw_output| glfw_output.getHeight(),
                BackendType.DRM => |drm_output| drm_output.getHeight(),
            };
        }

        pub fn shouldClose(self: Self) bool {
            return switch (self.backend) {
                BackendType.Headless => |headless_output| headless_output.shouldClose(),
                BackendType.GLFW => |glfw_output| glfw_output.shouldClose(),
                BackendType.DRM => |drm_output| drm_output.shouldClose(),
            };
        }

        pub fn addToEpoll(self: *Self) !void {
            return switch (self.backend) {
                BackendType.Headless => {},
                BackendType.GLFW => {},
                BackendType.DRM => |*drm_output| try drm_output.addToEpoll(),
            };
        }

        pub fn deinit(self: *Self) !void {
            try self.data.deinit();

            return switch (self.backend) {
                BackendType.Headless => |*headless_output| headless_output.deinit(),
                BackendType.GLFW => |*glfw_output| glfw_output.deinit(),
                BackendType.DRM => |*drm_output| drm_output.deinit(),
                else => return,
            };
        }
    };
}

pub fn Backend(comptime T: type) type {
    return union(BackendType) {
        Headless: HeadlessBackend,
        GLFW: GLFWBackend,
        DRM: DRMBackend,

        const Self = @This();

        pub fn init(backend_type: BackendType) !Self {
            return switch (backend_type) {
                BackendType.Headless => Self { .Headless = try headless.init() },
                BackendType.GLFW => Self { .GLFW = try glfw.init() },
                BackendType.DRM => Self { .DRM = try drm.init() },
            };
        }

        pub fn addToEpoll(self: *Self) !void {
            return switch (self.*) {
                BackendType.Headless => {},
                BackendType.GLFW => {},
                BackendType.DRM => |*drm_backend| try drm_backend.addToEpoll(),
            };
        }

        pub fn wait(self: Self) i32 {
            return switch (self) {
                BackendType.Headless => |headless_backend| -1,
                BackendType.GLFW => |glfw_backend| 10,
                BackendType.DRM => -1,
            };
        }

        pub fn name(self: Self) []const u8 {
            return switch (self) {
                BackendType.Headless => "Headless",
                BackendType.GLFW => "GLFW",
                BackendType.DRM => "DRM",
            };
        }

        pub fn newOutput(self: *Backend(T), w: i32, h: i32) !BackendOutput(T) {
            var output_backend = switch (self.*) {
                BackendType.Headless => |*headless_backend| OutputBackend{ .Headless = try headless_backend.newOutput(w, h) },
                BackendType.GLFW => |*glfw_backend| OutputBackend{ .GLFW = try glfw_backend.newOutput(w, h) },
                BackendType.DRM => |*drm_backend| OutputBackend{ .DRM = try drm_backend.newOutput() },
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
                BackendType.DRM => |drm_backend| drm_backend.deinit(),
            };
        }
    };
}

pub fn detect() BackendType {
    if (std.os.getenv("DISPLAY")) |display| {
        return BackendType.GLFW;
    }

    return BackendType.DRM;
}

pub const BackendFns = struct {
    keyboard: ?fn (u32, u32, u32) anyerror!void,
    mouseClick: ?fn (u32, u32, u32) anyerror!void,
    mouseMove: ?fn (u32, f64, f64) anyerror!void,
    pageFlip: ?fn () anyerror!void,
};

pub var BACKEND_FNS: BackendFns = makeBackendFns();

fn makeBackendFns() BackendFns{
    return BackendFns {
        .keyboard = null,
        .mouseClick = null,
        .mouseMove = null,
        .pageFlip = null,
    };
}