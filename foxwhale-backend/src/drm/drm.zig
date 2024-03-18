const std = @import("std");
const linux = std.os.linux;

const c = @cImport({
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
});

// const epoll = @import("../../epoll.zig");
// const Dispatchable = @import("../../epoll.zig").Dispatchable;

pub const DRM = struct {
    fd: i32,
    conn_id: u32,
    conn: c.drmModeConnectorPtr,
    mode_info: c.drmModeModeInfoPtr,
    crtc_id: u32,
    crtc: c.drmModeCrtcPtr,
    fb: ?u32,
    // dispatchable: Dispatchable,

    pub fn init() !DRM {
        std.log.warn("Loading DRM\n", .{});
        const fd: i32 = @intCast(linux.open("/dev/dri/card0", linux.O.RDWR, 0));
        const r = c.drmModeGetResources(fd);
        defer c.drmModeFreeResources(r);
        const n: usize = @intCast(r.*.count_connectors);
        std.log.warn("drm: resources: {any}, {any}\n", .{ r, n });

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const id = r.*.connectors[i];
            const conn = c.drmModeGetConnector(fd, id);
            std.log.warn("connector id: {}\n", .{id});

            if (conn.*.connection == c.DRM_MODE_CONNECTED and conn.*.encoder_id != 0) {
                const enc = c.drmModeGetEncoder(fd, conn.*.encoder_id);
                defer c.drmModeFreeEncoder(enc);

                return .{
                    .fd = fd,
                    .conn_id = id,
                    .conn = conn,
                    .mode_info = conn.*.modes,
                    .crtc_id = enc.*.crtc_id,
                    .crtc = c.drmModeGetCrtc(fd, enc.*.crtc_id),
                    .fb = null,
                    // .dispatchable = Dispatchable{
                    //     .impl = dispatch,
                    // },
                };
            }
        }

        return error.NoConnectorFound;
    }

    pub fn modeWidth(self: DRM) i32 {
        return self.mode_info.*.hdisplay;
    }

    pub fn modeHeight(self: DRM) i32 {
        return self.mode_info.*.vdisplay;
    }

    pub fn modeAddFb(self: DRM, depth: u8, bpp: u8, pitch: u32, handle: u32, fb: *u32) i32 {
        return c.drmModeAddFB(
            self.fd,
            self.mode_info.*.hdisplay,
            self.mode_info.*.vdisplay,
            depth,
            bpp,
            pitch,
            handle,
            fb,
        );
    }

    pub fn modePageFlip(self: DRM, fb: u32) i32 {
        return c.drmModePageFlip(
            self.fd,
            self.crtc_id,
            fb,
            1,
            null,
        );
    }

    pub fn modeRmFb(self: DRM) !void {
        if (self.fb) |fb| {
            if (c.drmModeRmFB(self.fd, fb) != 0) {
                return error.DrmModeRmFBFailed;
            }
            return;
        }

        return error.NoFbToRemove;
    }

    // pub fn addToEpoll(self: *DRM) !void {
    //     try epoll.addFd(self.fd, &self.dispatchable);
    // }

    pub fn isPageFlipScheduled() bool {
        return PAGE_FLIP_SCHEDULED;
    }

    pub fn schedulePageFlip() void {
        PAGE_FLIP_SCHEDULED = true;
    }
};

// pub fn dispatch(
//     dispatchable: *Dispatchable,
//     _: usize, // event_type
// ) anyerror!void {
//     const drm = @fieldParentPtr(DRM, "dispatchable", dispatchable);

//     _ = c.drmHandleEvent(drm.fd, &event_handler);
// }

var event_handler = c.drmEventContext{
    .version = 3,
    .vblank_handler = null,
    .page_flip_handler = null,
    .page_flip_handler2 = handlePageFlip,
    .sequence_handler = null,
};

var PAGE_FLIP_SCHEDULED: bool = false;
fn handlePageFlip(
    _: i32, // fd
    _: u32, // sequence
    _: u32, // tv_sec
    _: u32, // tv_usec
    _: u32, // crtc_id
    _: ?*anyopaque, // user_data
) callconv(.C) void {
    PAGE_FLIP_SCHEDULED = false;
}
