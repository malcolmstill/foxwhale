const c = @cImport({
    @cInclude("gbm.h");
});
const DRM = @import("drm.zig").DRM;

pub const GBM = struct {
    device: *c.gbm_device,
    surface: ?*c.gbm_surface,
    bo: ?*c.gbm_bo,

    pub fn init(drm: *DRM) !GBM {
        const device = c.gbm_create_device(drm.fd) orelse return error.GBMCreateDeviceFailed;

        const surface = c.gbm_surface_create(
            device.?,
            @intCast(drm.modeWidth()),
            @intCast(drm.modeHeight()),
            c.GBM_BO_FORMAT_XRGB8888,
            c.GBM_BO_USE_SCANOUT | c.GBM_BO_USE_RENDERING,
        ) orelse return error.GBMSurfaceCreateFailed;

        return .{
            .device = device,
            .surface = surface,
            .bo = null,
        };
    }

    pub fn surfaceLockFrontBuffer(self: GBM) ?*c.gbm_bo {
        return c.gbm_surface_lock_front_buffer(self.surface);
    }

    pub fn surfaceReleaseBuffer(self: GBM) void {
        _ = c.gbm_surface_release_buffer(self.surface, self.bo);
    }

    pub fn boGetHandle(bo: *c.gbm_bo) c.union_gbm_bo_handle {
        return c.gbm_bo_get_handle(bo);
    }

    pub fn boGetStride(bo: *c.gbm_bo) u32 {
        return c.gbm_bo_get_stride(bo);
    }
};
