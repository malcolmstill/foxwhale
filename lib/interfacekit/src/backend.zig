const std = @import("std");
const X11 = @import("x11.zig").X11;
const X11Output = @import("x11.zig").X11Output;
const Event = @import("../subsystem.zig").Event;
const SubsystemIterator = @import("../subsystem.zig").SubsystemIterator;

pub const BackendType = enum {
    x11,
    // DRM,
};

pub const Backend = union(BackendType) {
    x11: X11,
    // DRM: DRMBackend,

    const Self = @This();

    pub const TargetEvent = struct {
        target: *BackendOutput,
        event: BackendEvent,
    };

    pub const BackendEventType = enum {
        sync,
        button_press,
        resize,
    };

    pub const BackendEvent = union(BackendEventType) {
        sync: u32,
        button_press: ButtonPress,
        resize: Resize,
    };

    pub const ButtonPress = struct {
        x: i16,
        y: i16,
    };

    pub const Resize = struct {
        width: i16,
        height: i16,
    };

    pub const Iterator = union(BackendType) {
        x11: X11.Iterator,

        pub fn init(backend: *Backend) SubsystemIterator {
            return switch (backend.*) {
                .x11 => |*b| SubsystemIterator{ .backend = Backend.Iterator{ .x11 = X11.Iterator.init(backend, b) } },
            };
        }

        pub fn next(self: *Iterator, events: u32) !?Event {
            return switch (self.*) {
                .x11 => |*i| try i.next(events),
            };
        }
    };

    pub fn init(backend_type: BackendType) !Backend {
        return switch (backend_type) {
            .x11 => Backend{ .x11 = try X11.init() },
            // BackendType.DRM => Self{ .DRM = try drm.new() },
        };
    }

    pub fn getFd(self: *Self) i32 {
        return switch (self.*) {
            .x11 => |b| b.fd,
            // BackendType.DRM => Self{ .DRM = try drm.new() },
        };
    }

    pub fn wait(self: Self) i32 {
        return switch (self) {
            .x11 => |_| -1,
            // BackendType.DRM => -1,
        };
    }

    pub fn name(self: Self) []const u8 {
        return switch (self) {
            .x11 => "X11",
            // BackendType.DRM => "DRM",
        };
    }

    pub fn newOutput(self: *Backend, w: i16, h: i16) !BackendOutput {
        return switch (self.*) {
            .x11 => |*x| BackendOutput{ .x11 = try x.newOutput(w, h) },
        };
    }

    pub fn deinit(self: *Self) void {
        return switch (self.*) {
            .x11 => |*o| o.deinit(),
            // BackendType.DRM => |*drm_backend| drm_backend.deinit(),
        };
    }
};

pub const BackendOutput = union(BackendType) {
    x11: X11Output,

    const Self = @This();

    pub fn begin(self: Self) !void {
        switch (self) {
            .x11 => |o| o.begin(),
            // BackendType.DRM => |drm_output| drm_output.begin(),
        }
    }

    pub fn end(self: Self) void {
        return switch (self) {
            .x11 => |o| o.end(),
            // BackendType.DRM => |drm_output| drm_output.end(),
        };
    }

    pub fn swap(self: *Self) !void {
        switch (self.*) {
            .x11 => |*o| try o.swap(),
            // BackendType.DRM => |*drm_output| try drm_output.swap(),
        }
    }

    pub fn isPageFlipScheduled(self: *Self) bool {
        return switch (self.*) {
            .x11 => false,
            // BackendType.DRM => |drm_output| drm_output.isPageFlipScheduled(),
        };
    }

    pub fn getWidth(self: *Self) i32 {
        return switch (self.*) {
            .x11 => |*o| o.getWidth(),
            // BackendType.DRM => |drm_output| drm_output.getWidth(),
        };
    }

    pub fn getHeight(self: *Self) i32 {
        return switch (self.*) {
            .x11 => |*o| o.getHeight(),
            // BackendType.DRM => |drm_output| drm_output.getHeight(),
        };
    }

    pub fn shouldClose(self: Self) bool {
        return switch (self) {
            .x11 => |o| o.shouldClose(),
            // BackendType.DRM => |drm_output| drm_output.shouldClose(),
        };
    }

    // pub fn addToEpol
    pub fn getFd(self: *Self) i32 {
        return switch (self.*) {
            .x11 => |o| o.getFd(),
            // BackendType.DRM => |*drm_output| try drm_output.addToEpoll(),
        };
    }

    pub fn deinit(self: *Self) !void {
        return switch (self.*) {
            .x11 => |o| o.deinit(),
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
        return BackendType.DRM;
    }
}
