const std = @import("std");
const Stalloc = @import("stalloc.zig").Stalloc;
const Backend = @import("backend/backend.zig").Backend;
const HeadlessOutput = @import("backend/headless.zig").HeadlessOutput;
const GLFWOutput = @import("backend/glfw.zig").GLFWOutput;

var OUTPUTS: Stalloc(void, Output, 64) = undefined;
// pub const Backend = union(BackendType) {
    // Headless: HeadlessBackend,
    // GLFW: GLFWBackend,

pub const OutputType = enum {
    Headless,
    GLFW,
};

pub const Output = union(OutputType) {
    // An output belongs to backend.
    // E.g. we might simultaneously have a some outputs
    // from GLFW and and DRM
    // backend: *Backend,

    Headless: HeadlessOutput,
    GLFW: GLFWOutput,

    const Self = @This();

    pub fn draw(self: Self) void {
        return switch (self) {
            OutputType.Headless => |headless_output| headless_output.draw(),
            OutputType.GLFW => |glfw_output| glfw_output.draw(),
        };
    }

    pub fn shouldClose(self: Self) bool {
        return switch (self) {
            OutputType.Headless => |headless_output| headless_output.shouldClose(),
            OutputType.GLFW => |glfw_output| glfw_output.shouldClose(),
        };
    }

    pub fn getWidth(self: Self) i32 {
        return switch (self) {
            OutputType.Headless => |headless_output| headless_output.getWidth(),
            OutputType.GLFW => |glfw_output| glfw_output.getWidth(),
        };
    }

    pub fn getHeight(self: Self) i32 {
        return switch (self) {
            OutputType.Headless => |headless_output| headless_output.getHeight(),
            OutputType.GLFW => |glfw_output| glfw_output.getHeight(),
        };
    }

    pub fn deinit(self: *Self) void {
        std.debug.warn("deinit output {}\n", .{});
    }
};

pub fn newOutput(backend: *Backend, width: i32, height: i32) !*Output {
    var output = try OUTPUTS.new(undefined);
    output.* = try backend.newOutput(width, height);
    return output;
}