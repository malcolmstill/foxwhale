const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const GLFWBackend = struct {
    window: *c.GLFWwindow,

    const Self = @This();
    
    pub fn draw(self: Self) void {
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(self.window);
    }

    pub fn wait(self: Self) i32 {
        return 10;
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
    c.glfwSwapInterval(1);
    c.glClearColor(1.0, 0.0, 0.0, 0.0);

    return GLFWBackend {
        .window = window,
    };
}
