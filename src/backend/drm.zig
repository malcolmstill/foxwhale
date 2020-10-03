const systemd = @import("drm/systemd.zig");
const Logind = @import("drm/systemd.zig").Logind;
const inputs = @import("drm/input.zig");
const Input = @import("drm/input.zig").Input;
const DRM = @import("drm/drm.zig").DRM;
const GBM = @import("drm/gbm.zig").GBM;
const EGL = @import("drm/egl.zig").EGL;

pub const DRMBackend = struct {
    systemd: Logind,
    input: Input,

    const Self = @This();

    pub fn init(self: *Self) !void {
        try self.input.addToEpoll();
        inputs.global_logind = &self.systemd;
    }

    pub fn newOutput(self: *Self) !DRMOutput {
        var drm = try DRM.init();
        // try drm.addToEpoll();
        var gbm = try GBM.init(&drm);
        var egl = try EGL.init(&gbm);

        return DRMOutput {
            .backend = self,
            .drm = drm,
            .gbm = gbm,
            .egl = egl,
        };
    }

    pub fn deinit(self: *Self) void {
        self.systemd.deinit();
        self.input.deinit();
    }
};

pub fn new() !DRMBackend {
    var sysd = try systemd.create();
    try sysd.init();

    var input = try Input.create(&sysd);
    // try input.addToEpoll();

    return DRMBackend {
        .systemd = sysd,
        .input = input,
    };
}

pub const DRMOutput = struct {
    backend: *DRMBackend,
    drm: DRM,
    gbm: GBM,
    egl: EGL,

    const Self = @This();

    pub fn addToEpoll(self: *Self) !void {
        try self.drm.addToEpoll();
    }

    pub fn begin(self: Self) void {
    }

    pub fn end(self: Self) void {
    }

    pub fn isPageFlipScheduled(self: Self) bool {
        return DRM.isPageFlipScheduled();
    }

    pub fn swap(self: *Self) !void {
        if (DRM.isPageFlipScheduled()) {
            return;
        }

        self.egl.swapBuffers();

        var new_bo = self.gbm.surfaceLockFrontBuffer();
        if (new_bo == null) {
            return error.SurfaceLockFrontBufferFailed;
        }

        var handle = GBM.boGetHandle(new_bo.?);
        var pitch = GBM.boGetStride(new_bo.?);

        var fb: u32 = 0;
        _ = self.drm.modeAddFb(24, 32, pitch, handle.u32, &fb);

        _ = self.drm.modePageFlip(fb);

        DRM.schedulePageFlip();

        if (self.gbm.bo) |bo| {
            _ = try self.drm.modeRmFb();
            self.gbm.surfaceReleaseBuffer();
        } 

        self.gbm.bo = new_bo.?;
        self.drm.fb = fb;        
    }

    pub fn getWidth(self: Self) i32 {
        return self.drm.modeWidth();
    }

    pub fn getHeight(self: Self) i32 {
        return self.drm.modeHeight();
    }

    pub fn shouldClose(self: Self) bool {
        return false;
    }

    pub fn deinit(self: *Self) void {
        self.egl.deinit();
    }
};