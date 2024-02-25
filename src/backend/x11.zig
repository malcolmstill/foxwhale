const std = @import("std");
const mem = std.mem;
const os = std.os;
const linux = os.linux;
const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES3/gl3.h");
    @cInclude("X11/Xlib-xcb.h");
});
const Event = @import("../subsystem.zig").Event;
const Backend = @import("backend.zig").Backend;

pub const X11 = struct {
    conn: *c.xcb_connection_t,
    fd: i32,
    display: *c.Display,
    outputs: std.ArrayList(X11Output),

    pub fn init(allocator: mem.Allocator) !X11 {
        const display: *c.Display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;
        const conn = c.XGetXCBConnection(display) orelse return error.FailedToGetXcbConnection;

        return X11{
            .conn = conn,
            .fd = c.xcb_get_file_descriptor(conn),
            .display = display,
            .outputs = std.ArrayList(X11Output).init(allocator),
        };
    }

    pub fn deinit(backend: *X11) void {
        backend.outputs.deinit();
    }

    pub const Iterator = struct {
        backend: *Backend,
        x11: *X11,
        count: usize = 0,

        pub fn init(backend: *Backend, x11: *X11) Iterator {
            return Iterator{
                .backend = backend,
                .x11 = x11,
            };
        }

        pub fn next(it: *Iterator, _: u32) !?Event {
            defer it.count += 1;
            if (c.xcb_poll_for_event(it.x11.conn)) |ev| {
                const mask: usize = 0x80;
                std.log.info("event response type = {}", .{ev.*.response_type});

                switch (ev.*.response_type & ~mask) {
                    c.XCB_BUTTON_PRESS => {
                        const press: *c.xcb_button_press_event_t = @ptrCast(ev);
                        std.log.info("button = {}x{}", .{ press.event_x, press.event_y });

                        return .{
                            .backend = .{
                                .backend = it.backend,
                                .output = press.event,
                                .event = .{
                                    .button_press = .{
                                        .x = press.event_x,
                                        .y = press.event_y,
                                    },
                                },
                            },
                        };
                    },
                    c.XCB_EXPOSE => {
                        const configure: *c.xcb_expose_event_t = @ptrCast(ev);

                        // For the moment we assume a small number of outputs (in practice)
                        // probably a fine assumption and simply loop over to find the
                        // targetted output.
                        for (it.x11.outputs.items) |*output| {
                            if (output.window_id != configure.window) continue;

                            output.width = configure.width;
                            output.height = configure.height;
                            c.glViewport(0, 0, output.width, output.height);

                            break;
                        }

                        return .{
                            .backend = .{
                                .backend = it.backend,
                                .output = configure.window,
                                .event = .{
                                    .resize = .{
                                        .width = @intCast(configure.width),
                                        .height = @intCast(configure.height),
                                    },
                                },
                            },
                        };
                    },
                    else => {
                        std.log.info("unknown event = {}", .{ev.*.response_type & ~mask});
                        return null;
                    },
                }
            }

            if (it.count == 0) {
                std.debug.assert(it.x11.outputs.items.len > 0);

                return .{
                    .backend = .{
                        .backend = it.backend,
                        .output = it.x11.outputs.items[0].window_id,
                        .event = .{
                            .sync = 0,
                        },
                    },
                };
            }

            return null;
        }
    };

    pub fn newOutput(backend: *X11, w: i16, h: i16) !*X11Output {
        const setup = c.xcb_get_setup(backend.conn);
        const iter = c.xcb_setup_roots_iterator(setup);
        const screen = iter.data;

        const mask = c.XCB_CW_EVENT_MASK;
        var valwin = [1]u32{c.XCB_EVENT_MASK_BUTTON_PRESS | c.XCB_EVENT_MASK_EXPOSURE};

        const window = c.xcb_generate_id(backend.conn);
        _ = c.xcb_create_window(
            backend.conn,
            c.XCB_COPY_FROM_PARENT,
            window,
            screen.*.root,
            0,
            0,
            @intCast(w),
            @intCast(h),
            10,
            c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            mask,
            &valwin,
        );

        const egl = try setupEgl(c.EGL_OPENGL_API, backend.display, window);

        const title = "Blit.kit: X11";
        _ = c.xcb_change_property(
            backend.conn,
            c.XCB_PROP_MODE_REPLACE,
            window,
            c.XCB_ATOM_WM_NAME,
            c.XCB_ATOM_STRING,
            8,
            title.len,
            title,
        );

        _ = c.xcb_map_window(backend.conn, window);

        _ = c.xcb_flush(backend.conn);

        std.log.info("egl = {}", .{egl});

        c.glClearColor(1.0, 0.0, 0.0, 0.0);

        const output = X11Output{
            .window_id = window,
            .backend = backend,
            .display = egl.display,
            .surface = egl.surface,
            .width = w,
            .height = h,
        };

        const output_ptr = try backend.outputs.addOne();
        output_ptr.* = output;

        return output_ptr;
    }
};

pub const X11Output = struct {
    window_id: u32,
    backend: *X11,
    display: c.EGLDisplay,
    surface: c.EGLSurface,
    width: i32,
    height: i32,

    pub fn getWidth(self: *X11Output) i32 {
        return self.width;
    }

    pub fn getHeight(self: *X11Output) i32 {
        return self.height;
    }

    pub fn swap(self: *X11Output) !void {
        _ = c.eglSwapBuffers(self.display, self.surface);
    }
};

pub const SurfacContext = struct {
    display: c.EGLDisplay,
    config: c.EGLConfig,
    context: c.EGLContext,
    surface: c.EGLSurface,
};

fn setupEgl(api: c.EGLint, native_display: c.EGLNativeDisplayType, native_window: c.EGLNativeWindowType) !SurfacContext {
    var ok: c.EGLBoolean = undefined;

    ok = c.eglBindAPI(@intCast(api));
    if (ok == c.EGL_FALSE) return error.EglFailedToBind;

    const display = c.eglGetDisplay(native_display);
    if (display == c.EGL_NO_DISPLAY) return error.EglGetDisplayFailed;

    var major: i32 = 0;
    var minor: i32 = 0;
    ok = c.eglInitialize(display, &major, &minor);
    if (ok == c.EGL_FALSE) return error.EglFailedToInitialise;
    std.log.info("EGL version = {}.{}", .{ major, minor });

    var config: c.EGLConfig = undefined;
    var num_config: c.EGLint = 0;

    ok = c.eglChooseConfig(display, &egl_config_attribs[0], &config, 1, &num_config);
    if (ok == c.EGL_FALSE) return error.EglFailedToInitialise;

    if (num_config == 0) return error.EglNoConfigs;

    const context = c.eglCreateContext(display, config, c.EGL_NO_CONTEXT, &egl_context_attribs[0]) orelse return error.EglContextCreationFailed;
    const surface = c.eglCreateWindowSurface(display, config, native_window, &egl_surface_attribs[0]) orelse return error.EglSurfaceCreationFailed;

    std.log.info("context = {?}, surface = {?}", .{ context, surface });

    ok = c.eglMakeCurrent(display, surface, surface, context);
    if (num_config == 0) return error.EglMakeCurrentFailed;

    // Check if surface is double buffered.
    var render_buffer: c.EGLint = undefined;
    ok = c.eglQueryContext(display, context, c.EGL_RENDER_BUFFER, &render_buffer);

    if (ok == c.EGL_FALSE) return error.EglQueryContextFailed;
    if (render_buffer == c.EGL_SINGLE_BUFFER) return error.EglSingleBuffered;

    return SurfacContext{
        .display = display,
        .config = config,
        .context = context,
        .surface = surface,
    };
}

const egl_config_attribs = [_]c.EGLint{
    c.EGL_COLOR_BUFFER_TYPE, c.EGL_RGB_BUFFER,
    c.EGL_BUFFER_SIZE,       32,
    c.EGL_RED_SIZE,          8,
    c.EGL_GREEN_SIZE,        8,
    c.EGL_BLUE_SIZE,         8,
    c.EGL_ALPHA_SIZE,        8,

    c.EGL_DEPTH_SIZE,        c.EGL_DONT_CARE,
    c.EGL_STENCIL_SIZE,      c.EGL_DONT_CARE,

    c.EGL_SAMPLE_BUFFERS,    0,
    c.EGL_SAMPLES,           0,

    c.EGL_SURFACE_TYPE,      c.EGL_WINDOW_BIT,
    c.EGL_RENDERABLE_TYPE,   c.EGL_OPENGL_BIT,

    c.EGL_NONE,
};

const egl_context_attribs = [_]c.EGLint{
    c.EGL_CONTEXT_MAJOR_VERSION, 3,
    c.EGL_CONTEXT_MINOR_VERSION, 3,
    // c.EGL_CONTEXT_CLIENT_VERSION, 3,
    c.EGL_NONE,
};

const egl_surface_attribs = [_]c.EGLint{
    c.EGL_RENDER_BUFFER, c.EGL_BACK_BUFFER,
    c.EGL_NONE,
};
