const std = @import("std");
const X11 = @import("x11.zig").X11;
const X11Output = @import("x11.zig").X11Output;

const DRMBackend = @import("drm.zig").DRMBackend;
const DRMOutput = @import("drm.zig").DRMOutput;
const Event = @import("../subsystem.zig").Event;
const SubsystemIterator = @import("../subsystem.zig").SubsystemIterator;

pub const BackendType = enum {
    x11,
    drm,
};

pub const Backend = union(BackendType) {
    x11: X11,
    drm: DRMBackend,

    pub const TargetEvent = struct {
        backend: *Backend,
        output: usize,
        event: BackendEvent,
    };

    pub const BackendEventType = enum {
        sync,
        key_press,
        button_press,
        mouse_move,
        resize,
    };

    pub const BackendEvent = union(BackendEventType) {
        sync: u32,
        key_press: KeyPress,
        button_press: ButtonPress,
        mouse_move: MouseMove,
        resize: Resize,
    };

    pub const KeyPress = struct {
        time: u32,
        button: u32,
        state: u32,
    };

    pub const ButtonPress = struct {
        x: i16,
        y: i16,
        button: u16,
        state: u32,
    };

    pub const MouseMove = struct {
        dx: f64,
        dy: f64,
    };

    pub const Resize = struct {
        width: i16,
        height: i16,
    };

    pub const Iterator = union(BackendType) {
        x11: X11.Iterator,
        drm: DRMBackend.Iterator,

        pub fn init(backend: *Backend) SubsystemIterator {
            return switch (backend.*) {
                .x11 => |*b| .{ .backend = .{ .x11 = X11.Iterator.init(backend, b) } },
                .drm => |*b| .{ .backend = .{ .drm = DRMBackend.Iterator.init(backend, b) } },
            };
        }

        pub fn next(it: *Iterator, events: u32) !?Event {
            return switch (it.*) {
                .x11 => |*i| try i.next(events),
                .drm => |*i| try i.next(events),
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, backend_type: BackendType) !Backend {
        return switch (backend_type) {
            .x11 => Backend{ .x11 = try X11.init(allocator) },
            .drm => Backend{ .drm = try DRMBackend.init(allocator) },
            // BackendType.DRM => Self{ .DRM = try drm.new() },
        };
    }

    pub fn deinit(backend: *Backend) void {
        return switch (backend.*) {
            .x11 => |*o| o.deinit(),
            .drm => |*o| o.deinit(),
            // BackendType.DRM => |*drm_backend| drm_backend.deinit(),
        };
    }

    pub fn getFd(backend: *Backend) i32 {
        return switch (backend.*) {
            .x11 => |b| b.fd,
            .drm => |b| b.fd,
            // BackendType.DRM => Self{ .DRM = try drm.new() },
        };
    }

    pub fn wait(backend: Backend) i32 {
        return switch (backend) {
            .x11 => |_| -1,
            .drm => |_| -1,
            // BackendType.DRM => -1,
        };
    }

    pub fn name(backend: Backend) []const u8 {
        return switch (backend) {
            .x11 => "X11",
            .drm => "DRM",
            // BackendType.DRM => "DRM",
        };
    }

    pub fn newOutput(backend: *Backend, w: i16, h: i16) !BackendOutput {
        return switch (backend.*) {
            .x11 => |*x| .{ .x11 = try x.newOutput(w, h) },
            .drm => |*x| .{ .drm = try x.newOutput(w, h) },
        };
    }
};

pub const BackendOutput = union(BackendType) {
    x11: *X11Output,
    drm: *DRMOutput,

    pub fn begin(backend_output: BackendOutput) !void {
        switch (backend_output) {
            .x11 => |o| o.begin(),
            .drm => |o| o.begin(),
            // BackendType.DRM => |drm_output| drm_output.begin(),
        }
    }

    pub fn end(backend_output: BackendOutput) void {
        return switch (backend_output) {
            .x11 => |o| o.end(),
            .drm => |o| o.end(),
            // BackendType.DRM => |drm_output| drm_output.end(),
        };
    }

    pub fn swap(backend_output: *BackendOutput) !void {
        switch (backend_output.*) {
            .x11 => |o| try o.swap(),
            .drm => |o| try o.swap(),
            // BackendType.DRM => |*drm_output| try drm_output.swap(),
        }
    }

    pub fn isPageFlipScheduled(backend_output: *BackendOutput) bool {
        return switch (backend_output.*) {
            .x11 => false,
            .drm => |d| d.isPageFlipScheduled(),
            // BackendType.DRM => |drm_output| drm_output.isPageFlipScheduled(),
        };
    }

    pub fn getWidth(backend_output: *BackendOutput) i32 {
        return switch (backend_output.*) {
            .x11 => |o| o.getWidth(),
            .drm => |o| o.getWidth(),
            // BackendType.DRM => |drm_output| drm_output.getWidth(),
        };
    }

    pub fn getHeight(backend_output: *BackendOutput) i32 {
        return switch (backend_output.*) {
            .x11 => |o| o.getHeight(),
            .drm => |o| o.getHeight(),
            // BackendType.DRM => |drm_output| drm_output.getHeight(),
        };
    }

    pub fn shouldClose(backend_output: BackendOutput) bool {
        return switch (backend_output) {
            .x11 => |o| o.shouldClose(),
            .drm => |o| o.shouldClose(),
            // BackendType.DRM => |drm_output| drm_output.shouldClose(),
        };
    }

    // pub fn addToEpol
    pub fn getFd(backend_output: *BackendOutput) i32 {
        return switch (backend_output.*) {
            .x11 => |o| o.getFd(),
            .drm => |o| o.getFd(),
            // BackendType.DRM => |*drm_output| try drm_output.addToEpoll(),
        };
    }

    pub fn deinit(backend_output: *BackendOutput) !void {
        return switch (backend_output.*) {
            .x11 => |o| o.deinit(),
            .drm => |o| o.deinit(),
            // BackendType.DRM => |*drm_output| drm_output.deinit(),
        };
    }
};

pub fn detect() BackendType {
    if (std.os.getenv("DISPLAY")) |_| {
        return .x11;
        // } else if (std.os.getenve("WAYLAND_DISPLAY")) {
        // return BackentType.Wayland;
    } else {
        return .drm;
    }
}
