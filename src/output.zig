const std = @import("std");
const Stalloc = @import("stalloc.zig").Stalloc;
const stalloc = @import("stalloc.zig");
const Backend = @import("backend/backend.zig").Backend;
const HeadlessOutput = @import("backend/headless.zig").HeadlessOutput;
const GLFWOutput = @import("backend/glfw.zig").GLFWOutput;

pub var OUTPUTS: Stalloc(void, Output, 16) = undefined;

pub const OutputType = enum {
    Headless,
    GLFW,
};

pub const Output = union(OutputType) {
    Headless: HeadlessOutput,
    GLFW: GLFWOutput,

    const Self = @This();

    pub fn begin(self: Self) void {
        return switch (self) {
            OutputType.Headless => |headless_output| {
                headless_output.begin();
            },
            OutputType.GLFW => |glfw_output| {
                glfw_output.begin();
            },
        };
    }

    pub fn swap(self: Self) void {
        return switch (self) {
            OutputType.Headless => |headless_output| {
                headless_output.swap();
            },
            OutputType.GLFW => |glfw_output| {
                glfw_output.swap();
            },
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
        OUTPUTS.deinit(self);
        return switch (self.*) {
            OutputType.Headless => |*headless_output| headless_output.deinit(),
            OutputType.GLFW => |*glfw_output| glfw_output.deinit(),
            else => return,
        };
    }
};

pub fn newOutput(backend: *Backend, width: i32, height: i32) !*Output {
    var output = try OUTPUTS.new(undefined);
    output.* = try backend.newOutput(width, height);
    return output;
}