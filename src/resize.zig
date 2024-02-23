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
        return Resize{
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

    pub fn resize(self: Resize, pointer_x: f64, pointer_y: f64) !void {
        const window = self.window;
        const client = window.client;

        const xdg_surface = window.xdg_surface_id orelse return;
        const xdg_toplevel = window.xdg_toplevel orelse return;

        const state = [_]wl.XdgToplevel.ResizeEdge{
            .activated,
            .resizing,
        };

        try xdg_toplevel.sendConfigure(self.newWidth(pointer_x), self.newHeight(pointer_y), state[0..]);
        try xdg_surface.sendConfigure(client.nextSerial());
    }

    fn newWidth(self: Resize, pointer_x: f64) i32 {
        const dx = switch (self.direction) {
            .bottom_right => pointer_x - self.pointer_x,
            .right => pointer_x - self.pointer_x,
            .top_right => pointer_x - self.pointer_x,
            .bottom_left => self.pointer_x - pointer_x,
            .left => self.pointer_x - pointer_x,
            .top_left => self.pointer_x - pointer_x,
            else => 0,
        };

        return self.width + @as(i32, @intFromFloat(dx));
    }

    fn newHeight(self: Resize, pointer_y: f64) i32 {
        const dy = switch (self.direction) {
            .bottom_right => pointer_y - self.pointer_y,
            .bottom => pointer_y - self.pointer_y,
            .bottom_left => pointer_y - self.pointer_y,
            .top_right => self.pointer_y - pointer_y,
            .top => self.pointer_y - pointer_y,
            .top_left => self.pointer_y - pointer_y,
            else => 0,
        };

        return self.height + @as(i32, @intFromFloat(dy));
    }

    pub fn offsetX(self: Resize, old_buffer_width: i32, new_buffer_width: i32) i32 {
        return switch (self.direction) {
            .bottom_left => old_buffer_width - new_buffer_width,
            .left => old_buffer_width - new_buffer_width,
            .top_left => old_buffer_width - new_buffer_width,
            else => 0,
        };
    }

    pub fn offsetY(self: Resize, old_buffer_height: i32, new_buffer_height: i32) i32 {
        return switch (self.direction) {
            .top_right => old_buffer_height - new_buffer_height,
            .top => old_buffer_height - new_buffer_height,
            .top_left => old_buffer_height - new_buffer_height,
            else => 0,
        };
    }
};
