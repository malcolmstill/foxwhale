const std = @import("std");
const backend = @import("backend.zig");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

var previous_x: f64 = 0;
var previous_y: f64 = 0;

pub const GLFWBackend = struct {
    windowCount: i32,
    hidden: *c.GLFWwindow,

    const Self = @This();

    pub fn init(self: *Self) !void {}

    pub fn newOutput(self: *Self, width: i32, height: i32) !GLFWOutput {
        var window = c.glfwCreateWindow(width, height, "foxwhale", null, self.hidden) orelse return error.GLFWWindowCreationFailed;

        c.glfwMakeContextCurrent(window);
        _ = c.glfwSetKeyCallback(window, keyCallback);
        _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);
        _ = c.glfwSetFramebufferSizeCallback(window, resizeCallback);
        _ = c.glfwSetCursorPosCallback(window, cursorPositionCallback);

        self.windowCount += 1;

        return GLFWOutput{
            .window = window,
            .backend = self,
        };
    }

    pub fn deinit(self: Self) void {
        c.glfwTerminate();
    }
};

pub fn new() !GLFWBackend {
    if (c.glfwInit() != 1) {
        return error.GLFWInitFailed;
    }
    errdefer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwSwapInterval(1);
    var hidden = c.glfwCreateWindow(1, 1, "foxwhale", null, null) orelse return error.GLFWWindowCreationFailed;

    return GLFWBackend{
        .windowCount = 0,
        .hidden = hidden,
    };
}

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        if (c.glfwGetInputMode(window, c.GLFW_CURSOR) == c.GLFW_CURSOR_DISABLED) {
            c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
        } else {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }

    if (backend.BACKEND_FNS.keyboard) |keyboard| {
        var time = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        keyboard(time, @intCast(u32, scancode - 8), @intCast(u32, action)) catch return;
    }
}

fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (action == c.GLFW_PRESS) {
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    }

    var button_code: u32 = switch (button) {
        0 => 0x110,
        else => 0x0,
    };

    if (backend.BACKEND_FNS.mouseClick) |mouseClick| {
        var time = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        mouseClick(time, @intCast(u32, button_code), @intCast(u32, action)) catch return;
    }
}

fn resizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glfwMakeContextCurrent(window);
    c.glViewport(0, 0, width, height);
}

fn cursorPositionCallback(window: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    var dx = x - previous_x;
    var dy = y - previous_y;
    previous_x = previous_x + dx;
    previous_y = previous_y + dy;
    if (backend.BACKEND_FNS.mouseMove) |mouseMove| {
        var time = @truncate(u32, @intCast(u64, std.time.milliTimestamp()));
        mouseMove(time, dx, dy) catch return;
    }
}

pub const GLFWOutput = struct {
    window: ?*c.GLFWwindow,
    backend: *GLFWBackend,

    const Self = @This();

    pub fn begin(self: Self) void {
        c.glfwPollEvents();
        c.glfwMakeContextCurrent(self.window);
    }

    pub fn end(self: Self) void {
        c.glfwMakeContextCurrent(self.backend.hidden);
    }

    pub fn swap(self: Self) void {
        c.glfwSwapBuffers(self.window);
    }

    pub fn shouldClose(self: Self) bool {
        return c.glfwWindowShouldClose(self.window) == 1;
    }

    pub fn getWidth(self: Self) i32 {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.window, &w, &h);

        return w;
    }

    pub fn getHeight(self: Self) i32 {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.window, &w, &h);

        return h;
    }

    pub fn deinit(self: *Self) void {
        c.glfwDestroyWindow(self.window);
        self.window = null;
    }
};
