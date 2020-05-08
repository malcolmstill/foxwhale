const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const GLFWBackend = struct {
    window: *c.GLFWwindow,

    const Self = @This();
    
    pub fn draw(self: Self) void {
        c.glfwPollEvents();
        c.glfwSwapBuffers(self.window);
    }

    pub fn shouldClose(self: Self) bool {
        return c.glfwWindowShouldClose(self.window) == 1;
    }

    pub fn width(self: Self) i32 {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.window, &w, &h);

        return w;
    }

    pub fn height(self: Self) i32 {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.window, &w, &h);

        return h;
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

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);

    var window = c.glfwCreateWindow(640, 480, "zig-wayland", null, null) orelse return error.GLFWWindowCreationFailed;

    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetKeyCallback(window, keyCallback);
    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);
    _ = c.glfwSetFramebufferSizeCallback(window, resizeCallback);

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

fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (action == c.GLFW_PRESS) {
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    }
}

fn resizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glfwMakeContextCurrent(window);
    c.glViewport(0, 0, width, height);
}