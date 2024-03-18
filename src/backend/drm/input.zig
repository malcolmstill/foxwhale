const std = @import("std");
const Logind = @import("systemd.zig").Logind;
const backend = @import("../backend.zig");

const epoll = @import("../../epoll.zig");
const Dispatchable = @import("../../epoll.zig").Dispatchable;
const c = @cImport({
    @cInclude("libudev.h");
    @cInclude("dirent.h");
    @cInclude("libinput.h");
});

pub var global_logind: *Logind = undefined;

pub const Input = struct {
    udev_context: ?*c.udev,
    context: ?*c.struct_libinput,
    fd: c_int,
    dispatchable: Dispatchable,

    pub fn create(l: *Logind) !Input {
        global_logind = l;
        const udev_context = c.udev_new();
        const ctx = c.libinput_udev_create_context(&input_interface, null, udev_context);
        if (ctx == null) {
            return error.UdevCreateContextFailed;
        }

        if (c.libinput_udev_assign_seat(ctx, "seat0") == -1) {
            return error.UdevAssignSeatFailed;
        }
        const fd = c.libinput_get_fd(ctx);

        return Input{
            .udev_context = udev_context,
            .context = ctx,
            .fd = fd,
            .dispatchable = Dispatchable{
                .impl = dispatch,
            },
        };
    }

    pub fn deinit(self: *Input) void {
        _ = c.libinput_unref(self.context);
    }

    fn getFd(self: *Input) i32 {
        return c.libinput_get_fd(self.context);
    }

    // pub fn addToEpoll(self: *Input) !void {
    //     try epoll.addFd(self.getFd(), &self.dispatchable);
    // }
};

const EventType = c.enum_libinput_event_type;

pub fn dispatch(
    dispatchable: *Dispatchable,
    _: usize, // event_type
) anyerror!void {
    const input = @fieldParentPtr(Input, "dispatchable", dispatchable);

    _ = c.libinput_dispatch(input.context);

    while (c.libinput_get_event(input.context)) |event| {
        const input_event_type = c.libinput_event_get_type(event);

        switch (input_event_type) {
            c.LIBINPUT_EVENT_DEVICE_ADDED => {
                const device = c.libinput_event_get_device(event);
                const name = c.libinput_device_get_name(device);
                std.log.warn("Added device: {s}\n", .{std.mem.span(name)});
                _ = c.libinput_device_ref(device);
                const seat = c.libinput_device_get_seat(device);
                _ = c.libinput_seat_ref(seat);
            },
            c.LIBINPUT_EVENT_DEVICE_REMOVED => std.log.warn("device removed\n", .{}),
            c.LIBINPUT_EVENT_KEYBOARD_KEY => {
                const keyboard_event = c.libinput_event_get_keyboard_event(event);
                const key = c.libinput_event_keyboard_get_key(keyboard_event);
                const state: u32 = @intCast(c.libinput_event_keyboard_get_key_state(keyboard_event));
                const time = c.libinput_event_keyboard_get_time(keyboard_event);

                if (backend.BACKEND_FNS.keyboard) |keyboard_fn| {
                    try keyboard_fn(time, key, state);
                }
            },
            c.LIBINPUT_EVENT_POINTER_BUTTON => {
                const mouse_button_event = c.libinput_event_get_pointer_event(event);
                const button = c.libinput_event_pointer_get_button(mouse_button_event);
                const state: u32 = @intCast(c.libinput_event_pointer_get_button_state(mouse_button_event));
                const time = c.libinput_event_pointer_get_time(mouse_button_event);

                if (backend.BACKEND_FNS.mouseClick) |mouseClick| {
                    try mouseClick(time, button, state);
                }
            },
            c.LIBINPUT_EVENT_POINTER_MOTION => {
                const pointer_event = c.libinput_event_get_pointer_event(event);
                const dx = c.libinput_event_pointer_get_dx(pointer_event);
                const dy = c.libinput_event_pointer_get_dy(pointer_event);
                const time = c.libinput_event_pointer_get_time(pointer_event);

                if (backend.BACKEND_FNS.mouseMove) |mouseMove| {
                    try mouseMove(time, dx, dy);
                }
            },
            c.LIBINPUT_EVENT_POINTER_AXIS => {
                const pointer_event = c.libinput_event_get_pointer_event(event);
                const vertical = c.LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL;
                const has_vertical = c.libinput_event_pointer_has_axis(pointer_event, @intCast(vertical));
                if (has_vertical != 0) {
                    const value = c.libinput_event_pointer_get_axis_value(pointer_event, @intCast(vertical));
                    const time = c.libinput_event_pointer_get_time(pointer_event);

                    if (backend.BACKEND_FNS.mouseAxis) |mouseAxis| {
                        try mouseAxis(time, c.LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL, value);
                    }
                }
            },
            else => std.log.warn("unhandled event\n", .{}),
        }

        c.libinput_event_destroy(event);
        _ = c.libinput_dispatch(input.context);
    }
}

pub fn open(
    path: [*c]const u8,
    _: c_int, // flags
    _: ?*anyopaque, // user_data
) callconv(.C) c_int {
    const fd = global_logind.open(path) catch {
        return -1;
    };
    return fd;
}

pub fn close(
    fd: c_int,
    _: ?*anyopaque, // user_data
) callconv(.C) void {
    _ = global_logind.close(fd) catch {
        return;
    };
    return;
}

const input_interface = c.struct_libinput_interface{
    .open_restricted = open,
    .close_restricted = close,
};
