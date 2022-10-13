const c = @cImport({
    @cInclude("EGL/egl.h");
});

const std = @import("std");
const GBM = @import("gbm.zig").GBM;

const default_config_attributes = [_]i32{
    c.EGL_RED_SIZE,   8,
    c.EGL_GREEN_SIZE, 8,
    c.EGL_BLUE_SIZE,  8,
    c.EGL_ALPHA_SIZE, 8,
    c.EGL_NONE,
};

const default_context_attributes = [_]i32{
    c.EGL_CONTEXT_MAJOR_VERSION, 3,
    c.EGL_CONTEXT_MINOR_VERSION, 3,
    c.EGL_NONE,
};

pub const EGL = struct {
    display: *anyopaque,
    context: *anyopaque,
    surface: *anyopaque,

    pub fn init(gbm: *GBM) !EGL {
        errdefer {
            std.log.err("EGL error = {}\n", .{c.eglGetError()});
        }

        glEGLImageTargetTexture2DOES = @ptrCast(?*const fn (i32, *anyopaque) callconv(.C) void, c.eglGetProcAddress("glEGLImageTargetTexture2DOES"));
        var display = c.eglGetDisplay(@ptrCast(c.EGLNativeDisplayType, gbm.device)) orelse return error.EGLGetDisplayError;

        var major: i32 = 0;
        var minor: i32 = 0;
        _ = c.eglInitialize(display, &major, &minor);
        std.log.warn("EGL version: {}.{}\n", .{ major, minor });

        var config: c.EGLConfig = undefined;
        var num_config: i32 = 0;
        if (c.eglChooseConfig(display, &default_config_attributes[0], &config, 1, &num_config) == c.EGL_FALSE) {
            return error.EGLChooseConfigFailed;
        }

        if (c.eglBindAPI(c.EGL_OPENGL_API) == c.EGL_FALSE) {
            return error.EGLBindAPIFailed;
        }

        var context = c.eglCreateContext(display, config, null, &default_context_attributes[0]) orelse return error.EGLCreateContextFailed;
        var surface = c.eglCreateWindowSurface(display, config, @ptrToInt(gbm.surface), null) orelse return error.EGLCreateWindowSurfaceFailed;

        var width: i32 = 0;
        var height: i32 = 0;
        _ = c.eglQuerySurface(display, surface, c.EGL_WIDTH, &width);
        _ = c.eglQuerySurface(display, surface, c.EGL_HEIGHT, &height);
        std.log.warn("egl wxh: {}x{}\n", .{ width, height });

        _ = c.eglMakeCurrent(display, surface, surface, context);

        return EGL{
            .display = display,
            .context = context,
            .surface = surface,
        };
    }

    pub fn deinit(self: EGL) void {
        const ds = c.eglDestroySurface(self.display, self.surface);
        _ = c.eglDestroyContext(self.display, self.context);
        _ = c.eglTerminate(self.display);
        std.log.warn("EGL deinit: {}\n", .{ds});
    }

    pub fn swapBuffers(self: EGL) void {
        _ = c.eglSwapBuffers(self.display, self.surface);
    }
};

pub var glEGLImageTargetTexture2DOES: ?*const fn (i32, *anyopaque) callconv(.C) void = undefined;
