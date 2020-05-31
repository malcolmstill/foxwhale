const c = @cImport({
    @cInclude("gbm.h");
});
const DRM = @import("drm.zig").DRM;

pub const GBM = struct {
    device: *c.gbm_device,
    surface: ?*c.gbm_surface,
    bo: ?*c.gbm_bo,

    pub fn init(drm: *DRM) !GBM {
        var device = c.gbm_create_device(drm.fd);
        if (device == null) {
            return error.GBMCreateDeviceFailed;
        }
        var surface = c.gbm_surface_create(
            device.?,
            @intCast(u32, drm.modeWidth()),
            @intCast(u32, drm.modeHeight()),
            c.GBM_BO_FORMAT_XRGB8888,
            c.GBM_BO_USE_SCANOUT|c.GBM_BO_USE_RENDERING,
        );
        if (surface == null) {
            return error.GBMSurfaceCreateFailed;
        }

        return GBM {
            .device = device.?,
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