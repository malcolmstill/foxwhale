
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

var global_logind: *Logind = undefined;

pub const Input = struct {
    udev_context: ?*c.udev,
    context: ?*c.struct_libinput,
    fd: c_int,
    dispatchable: Dispatchable,

    pub fn create(l: *Logind) !Input {
        global_logind = l;
        var udev_context = c.udev_new();
        var ctx = c.libinput_udev_create_context(&input_interface, null, udev_context);
        if (ctx == null) {
            return error.UdevCreateContextFailed;
        }

        if (c.libinput_udev_assign_seat(ctx, "seat0") == -1) {
            return error.UdevAssignSeatFailed;
        }
        var fd = c.libinput_get_fd(ctx);

        return Input {
            .udev_context = udev_context,
            .context = ctx,
            .fd = fd,
            .dispatchable = Dispatchable {
                .impl = dispatch,
            },
        };
    }

    fn getFd(self: *Input) i32 {
        return c.libinput_get_fd(self.context);
    }

    pub fn addToEpoll(self: *Input) !void {
        try epoll.addFd(self.getFd(), &self.dispatchable);
    }
};

const EventType = c.enum_libinput_event_type;

pub fn dispatch(dispatchable: *Dispatchable, event_type: usize) anyerror!void {
    var input = @fieldParentPtr(Input, "dispatchable", dispatchable);
    
    _ = c.libinput_dispatch(input.context);

    while(c.libinput_get_event(input.context)) |event| {
        var input_event_type = c.libinput_event_get_type(event);
        switch (input_event_type) {
            EventType.LIBINPUT_EVENT_DEVICE_ADDED => {
                var device = c.libinput_event_get_device(event);
                var name = c.libinput_device_get_name(device);
                std.debug.warn("Added device: {}\n", .{std.mem.span(name)});
                _ = c.libinput_device_ref(device);
                var seat = c.libinput_device_get_seat(device);
                _ = c.libinput_seat_ref(seat);
            },
            EventType.LIBINPUT_EVENT_DEVICE_REMOVED => std.debug.warn("device removed\n", .{}),
            EventType.LIBINPUT_EVENT_KEYBOARD_KEY => {
                var keyboard_event = c.libinput_event_get_keyboard_event(event);
                var key = c.libinput_event_keyboard_get_key(keyboard_event);
                var state = @intCast(u32, @enumToInt(c.libinput_event_keyboard_get_key_state(keyboard_event)));
                var time = c.libinput_event_keyboard_get_time(keyboard_event);

                if (backend.BACKEND_FNS.keyboard) |keyboard_fn| {
                    try keyboard_fn(time, key, state);
                }
            },
            EventType.LIBINPUT_EVENT_POINTER_BUTTON => {
                var mouse_button_event = c.libinput_event_get_pointer_event(event);
                var button = c.libinput_event_pointer_get_button(mouse_button_event);
                var state = @intCast(u32, @enumToInt(c.libinput_event_pointer_get_button_state(mouse_button_event)));
                var time = c.libinput_event_pointer_get_time(mouse_button_event);

                if (backend.BACKEND_FNS.mouseClick) |mouseClick| {
                    try mouseClick(time, button, state);
                }
            },
            EventType.LIBINPUT_EVENT_POINTER_MOTION => {
                var pointer_event = c.libinput_event_get_pointer_event(event);
                var dx = c.libinput_event_pointer_get_dx(pointer_event);
                var dy = c.libinput_event_pointer_get_dy(pointer_event);
                var time = c.libinput_event_pointer_get_time(pointer_event);

                if (backend.BACKEND_FNS.mouseMove) |mouseMove| {
                    try mouseMove(time, dx, dy);
                }
            },            
            else => std.debug.warn("unhandled event\n", .{}),
        }

        c.libinput_event_destroy(event);
        _ = c.libinput_dispatch(input.context);
    }
}

pub fn open(path: [*c]const u8, flags: c_int, user_data: ?*c_void) callconv(.C) c_int {
    var fd = global_logind.open(path) catch
        |e| {
            return -1;
    };
    return fd;
}

pub fn close(fd: c_int, user_data: ?*c_void) callconv(.C) void {
    var x = global_logind.close(fd) catch
        |e| {
            return;
    };
    return;
}

const input_interface = c.struct_libinput_interface {
    .open_restricted = open,
    .close_restricted = close,
};