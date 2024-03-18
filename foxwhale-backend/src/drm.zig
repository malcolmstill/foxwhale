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
        const egl = try EGL.init(&gbm);

        return .{
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

    const input = try Input.create(&sysd);
    // try input.addToEpoll();

    return DRMBackend{
        .systemd = sysd,
        .input = input,
    };
}

pub const DRMOutput = struct {
    backend: *DRMBackend,
    drm: DRM,
    gbm: GBM,
    egl: EGL,

    pub fn addToEpoll(drm_output: *DRMOutput) !void {
        try drm_output.drm.addToEpoll();
    }

    pub fn begin(_: DRMOutput) void {}

    pub fn end(_: DRMOutput) void {}

    pub fn isPageFlipScheduled(_: DRMOutput) bool {
        return DRM.isPageFlipScheduled();
    }

    pub fn swap(drm_output: *DRMOutput) !void {
        if (DRM.isPageFlipScheduled()) return;

        drm_output.egl.swapBuffers();

        const new_bo = drm_output.gbm.surfaceLockFrontBuffer() orelse return error.SurfaceLockFrontBufferFailed;

        const handle = GBM.boGetHandle(new_bo);
        const pitch = GBM.boGetStride(new_bo);

        var fb: u32 = 0;
        _ = drm_output.drm.modeAddFb(24, 32, pitch, handle.u32, &fb);

        _ = drm_output.drm.modePageFlip(fb);

        DRM.schedulePageFlip();

        if (drm_output.gbm.bo) |_| {
            _ = try drm_output.drm.modeRmFb();
            drm_output.gbm.surfaceReleaseBuffer();
        }

        drm_output.gbm.bo = new_bo;
        drm_output.drm.fb = fb;
    }

    pub fn getWidth(drm_output: DRMOutput) i32 {
        return drm_output.drm.modeWidth();
    }

    pub fn getHeight(drm_output: DRMOutput) i32 {
        return drm_output.drm.modeHeight();
    }

    pub fn shouldClose(_: DRMOutput) bool {
        return false;
    }

    pub fn deinit(drm_output: *DRMOutput) void {
        drm_output.egl.deinit();
    }
};
