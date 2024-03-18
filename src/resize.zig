const std = @import("std");
const builtin = @import("builtin");
const endian = builtin.cpu.arch.endian();
const wl = @import("client.zig").wl;
const Window = @import("resource/window.zig").Window;
const XdgConfiguration = @import("resource/window.zig").XdgConfiguration;

pub const Resize = struct {
    window: *Window,
    window_x: i32,
    window_y: i32,
    pointer_x: f64,
    pointer_y: f64,
    width: i32,
    height: i32,
    direction: wl.XdgToplevel.ResizeEdge,

    pub fn init(window: *Window, window_x: i32, window_y: i32, pointer_x: f64, pointer_y: f64, width: i32, height: i32, direction: wl.XdgToplevel.ResizeEdge) Resize {
        return .{
            .window = window,
            .window_x = window_x,
            .window_y = window_y,
            .pointer_x = pointer_x,
            .pointer_y = pointer_y,
            .width = width,
            .height = height,
            .direction = direction,
        };
    }

    pub fn configure(resize: Resize, pointer_x: f64, pointer_y: f64) !void {
        const window = resize.window;
        const client = window.client;

        const xdg_surface = window.xdg_surface orelse return;
        const xdg_toplevel = window.xdg_toplevel orelse return;

        var state: [8]u8 = undefined;
        var fbs = std.io.fixedBufferStream(state[0..]);

        try fbs.writer().writeInt(u32, @intFromEnum(wl.XdgToplevel.State.activated), endian);
        try fbs.writer().writeInt(u32, @intFromEnum(wl.XdgToplevel.State.resizing), endian);

        try xdg_toplevel.sendConfigure(resize.newWidth(pointer_x), resize.newHeight(pointer_y), state[0..]);
        try xdg_surface.sendConfigure(client.nextSerial());
    }

    fn newWidth(resize: Resize, pointer_x: f64) i32 {
        const dx = switch (resize.direction) {
            .bottom_right => pointer_x - resize.pointer_x,
            .right => pointer_x - resize.pointer_x,
            .top_right => pointer_x - resize.pointer_x,
            .bottom_left => resize.pointer_x - pointer_x,
            .left => resize.pointer_x - pointer_x,
            .top_left => resize.pointer_x - pointer_x,
            else => 0,
        };

        return resize.width + @as(i32, @intFromFloat(dx));
    }

    fn newHeight(resize: Resize, pointer_y: f64) i32 {
        const dy = switch (resize.direction) {
            .bottom_right => pointer_y - resize.pointer_y,
            .bottom => pointer_y - resize.pointer_y,
            .bottom_left => pointer_y - resize.pointer_y,
            .top_right => resize.pointer_y - pointer_y,
            .top => resize.pointer_y - pointer_y,
            .top_left => resize.pointer_y - pointer_y,
            else => 0,
        };

        return resize.height + @as(i32, @intFromFloat(dy));
    }

    pub fn offsetX(resize: Resize, old_buffer_width: i32, new_buffer_width: i32) i32 {
        return switch (resize.direction) {
            .bottom_left => old_buffer_width - new_buffer_width,
            .left => old_buffer_width - new_buffer_width,
            .top_left => old_buffer_width - new_buffer_width,
            else => 0,
        };
    }

    pub fn offsetY(resize: Resize, old_buffer_height: i32, new_buffer_height: i32) i32 {
        return switch (resize.direction) {
            .top_right => old_buffer_height - new_buffer_height,
            .top => old_buffer_height - new_buffer_height,
            .top_left => old_buffer_height - new_buffer_height,
            else => 0,
        };
    }
};
