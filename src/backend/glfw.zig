const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const GLFWBackend = struct {
    window: *c.GLFWwindow,

    const Self = @This();
    
    pub fn draw(self: Self) void {
        c.glfwPollEvents();
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(self.window);
    }

    pub fn shouldClose(self: Self) bool {
        return c.glfwWindowShouldClose(self.window) == 1;
    }

    pub fn deinit(self: Self) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }
};

pub fn init() !GLFWBackend {
    if(c.glfwInit() != 1) {
        return error.GLFWInitFailed;
    }
    errdefer c.glfwTerminate();

    var window = c.glfwCreateWindow(640, 480, "zig-wayland", null, null) orelse return error.GLFWWindowCreationFailed;

    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetKeyCallback(window, keyCallback);
    _ = c.glfwSetWindowFocusCallback(window, windowFocusCallback);
    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);

    c.glfwSwapInterval(1);
    c.glClearColor(0.3, 0.3, 0.35, 0.0);

    return GLFWBackend {
        .window = window,
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
}

fn windowFocusCallback(window: ?*c.GLFWwindow, focussed: c_int) callconv(.C) void {
    if (focussed == c.GLFW_TRUE) {
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    } else {
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
    }
}

fn  mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (action == c.GLFW_PRESS) {
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    }
}