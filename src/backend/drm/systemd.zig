const std = @import("std");
const os = std.os;
const linux = std.os.linux;
// const file = std.file;
const AutoHashMap = std.AutoHashMap;

const c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/stat.h");
    @cInclude("fcntl.h");
    @cInclude("stdlib.h");
    @cInclude("unistd.h");
    @cInclude("systemd/sd-bus.h");
    @cInclude("systemd/sd-login.h");
});

pub const Logind = struct {
    fd: c_int,
    bus: *c.struct_sd_bus,
    session_path: [256]u8,
    session_id: [*c]u8,
    devices: AutoHashMap(c_int, []u8),

    pub fn init(self: *Logind) !void {
        var session_path = try getSessionPath(self.bus, self.session_id);
        std.mem.copy(u8, self.session_path[0..std.mem.len(session_path)], std.mem.span(session_path));

        try activate(self.bus, self.session_path);
        try takeControl(self.bus, self.session_path);
    }

    pub fn deinit(self: *Logind) void {
        releaseControl(self.bus, self.session_path) catch {};
        c.free(self.session_id);

        // var it = self.devices.iterator();
        // while(it.next()) |device| {
        //     std.heap.c_allocator.free(device.value);
        // }

        // self.devices.deinit();
    }

    pub fn open(self: *Logind, path: [*:0]const u8) !i32 {
        var path_copy = try std.heap.c_allocator.alloc(u8, 256);
        std.mem.copy(u8, path_copy[0..], std.mem.span(path));

        var fd = try takeDevice(self.bus, self.session_path, path);
        _ = try self.devices.put(fd, path_copy);

        return fd;
    }

    pub fn close(self: *Logind, fd: i32) !void {
        _ = try releaseDevice(self.bus, self.session_path, fd);
        _ = linux.close(fd);
        if (self.devices.fetchRemove(fd)) |path| {
            std.heap.c_allocator.free(path.value);
        }
    }
};

pub fn create() !Logind {
    var session_id = try pidGetSession();
    var bus = try busDefaultSystem();
    var fd = try busGetFd(bus);

    return Logind{
        .fd = fd,
        .bus = bus,
        .session_id = session_id,
        .session_path = [_]u8{0} ** 256,
        .devices = AutoHashMap(c_int, []u8).init(std.heap.c_allocator),
    };
}

fn pidGetSession() ![*c]u8 {
    var pid = linux.getpid();
    var session: [*c]u8 = undefined;

    var err = c.sd_pid_get_session(pid, &session);
    if (err < 0) {
        return error.NotPartOfLoginSession;
    }

    return session;
}

fn busDefaultSystem() !*c.struct_sd_bus {
    var b: *c.struct_sd_bus = undefined;
    var err = c.sd_bus_default_system(@ptrCast([*c]?*c.struct_sd_bus, &b));
    if (err < 0) {
        return error.GetDefaultSystemBusFailed;
    }

    return b;
}

fn busGetFd(bus: *c.struct_sd_bus) !i32 {
    var fd = c.sd_bus_get_fd(bus);
    if (fd < 0) {
        return error.GetBusFDFailed;
    }
    return fd;
}

fn getSessionPath(bus: *c.struct_sd_bus, session_id: [*c]u8) ![*c]u8 {
    var msg: *c.sd_bus_message = undefined;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var res = c.sd_bus_call_method(bus, "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "GetSession", &err, @ptrCast([*c]?*c.struct_sd_bus_message, &msg), "s", &session_id[0]);
    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (res < 0) {
        return error.GetSessionFailed;
    }

    var session_path: [*c]u8 = undefined;
    res = c.sd_bus_message_read(msg, "o", &session_path);
    if (res < 0) {
        return error.MessageReadFailed;
    }

    return session_path;
}

fn activate(bus: *c.struct_sd_bus, session_path: [256]u8) !void {
    var msg: ?*c.sd_bus_message = null;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var res = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        session_path[0..],
        "org.freedesktop.login1.Session",
        "Activate",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "",
    );
    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (res < 0) {
        return error.ActivateFailed;
    }

    return;
}

fn takeControl(bus: *c.struct_sd_bus, session_path: [256]u8) !void {
    var msg: ?*c.sd_bus_message = null;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var res = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        session_path[0..],
        "org.freedesktop.login1.Session",
        "TakeControl",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "b",
        false,
    );
    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (res < 0) {
        return error.TakeControlFailed;
    }

    return;
}

fn releaseControl(bus: *c.struct_sd_bus, session_path: [256]u8) !void {
    var msg: *c.sd_bus_message = undefined;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var res = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        session_path[0..],
        "org.freedesktop.login1.Session",
        "ReleaseControl",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "",
    );
    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (res < 0) {
        return error.ReleaseControlFailed;
    }

    return;
}

fn takeDevice(bus: *c.struct_sd_bus, session_path: [256]u8, path: [*:0]const u8) !i32 {
    var msg: *c.sd_bus_message = undefined;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var st: os.Stat = undefined;
    var res = linux.stat(path, &st);

    if (res < 0) {
        return error.StatFailed;
    }

    var rs = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        session_path[0..session_path.len],
        "org.freedesktop.login1.Session",
        "TakeDevice",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "uu",
        dev_major(st.rdev),
        dev_minor(st.rdev),
    );

    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (rs < 0) {
        return error.TakeDeviceFailed;
    }

    var fd: c_int = -1;
    var paused: c_int = 0;

    rs = c.sd_bus_message_read(msg, "hb", &fd, &paused);
    if (rs < 0) {
        return error.MessageReadFailed;
    }

    // fd = c.fcntl(fd, c.F_DUPFD_CLOEXEC, 0);
    fd = c.dup(fd);
    if (fd < 0) {
        return error.FcntlFailed;
    }

    return fd;
}

fn releaseDevice(bus: *c.struct_sd_bus, session_path: [256]u8, fd: i32) !i32 {
    var msg: *c.sd_bus_message = undefined;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var st: os.Stat = undefined;
    var res = linux.fstat(fd, &st);

    if (res < 0) {
        return error.StatFailed;
    }

    var rs = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        session_path[0..session_path.len],
        "org.freedesktop.login1.Session",
        "ReleaseDevice",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "uu",
        dev_major(st.rdev),
        dev_minor(st.rdev),
    );
    defer {
        c.sd_bus_error_free(&err);
        // _ = c.sd_bus_message_unref(msg);
    }

    if (rs < 0) {
        return error.ReleaseDeviceFailed;
    }

    return fd;
}

pub fn changeVt(bus: *c.struct_sd_bus, vt: i32) !void {
    var msg: *c.sd_bus_message = undefined;
    var err: c.sd_bus_error = c.sd_bus_error{
        .name = undefined,
        .message = undefined,
        ._need_free = 0,
    };

    var res = c.sd_bus_call_method(
        bus,
        "org.freedesktop.login1",
        "/org/freedesktop/login1/seat/self",
        "org.freedesktop.login1.Seat",
        "SwitchTo",
        &err,
        @ptrCast([*c]?*c.struct_sd_bus_message, &msg),
        "u",
        vt,
    );
    defer {
        c.sd_bus_error_free(&err);
        _ = c.sd_bus_message_unref(msg);
    }

    if (res < 0) {
        return error.ChangeVTFailed;
    }

    return;
}

fn dev_major(arg___dev: c.dev_t) callconv(.C) c_ulong {
    var __dev = arg___dev;
    var __major: c_ulong = undefined;
    __major = @bitCast(c_uint, @truncate(c_uint, ((__dev & @bitCast(c.dev_t, @as(c_ulong, @as(c_uint, 1048320)))) >> @intCast(@import("std").math.Log2Int(c_ulong), 8))));
    __major |= ((__dev & @bitCast(c.dev_t, @as(c_ulong, 18446726481523507200))) >> @intCast(@import("std").math.Log2Int(c_ulong), 32));
    return __major;
}
fn dev_minor(arg___dev: c.dev_t) callconv(.C) c_ulong {
    var __dev = arg___dev;
    var __minor: c_ulong = undefined;
    __minor = @bitCast(c_uint, @truncate(c_uint, ((__dev & @bitCast(c.dev_t, @as(c_ulong, @as(c_uint, 255)))) >> @intCast(@import("std").math.Log2Int(c_ulong), 0))));
    __minor |= ((__dev & @bitCast(c.dev_t, @as(c_ulong, 17592184995840))) >> @intCast(@import("std").math.Log2Int(c_ulong), 12));
    return __minor;
}
