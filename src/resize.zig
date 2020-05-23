const prot = @import("protocols.zig");
const Window = @import("window.zig").Window;
const XdgConfiguration = @import("window.zig").XdgConfiguration;
const edge = prot.xdg_toplevel_resize_edge;

pub const Resize = struct {
    window: *Window,
    window_x: i32,
    window_y: i32,
    pointer_x: f64,
    pointer_y: f64,
    width: i32,
    height: i32,
    direction: u32,

    pub fn resize(self: Resize, pointer_x: f64, pointer_y: f64) !void {
        var window = self.window;
        var client = window.client;

        if (window.xdg_surface_id) |xdg_surface_id| {
            if (client.context.get(xdg_surface_id)) |xdg_surface| {
                if (window.xdg_toplevel_id) |xdg_toplevel_id| {
                    if (client.context.get(xdg_toplevel_id)) |xdg_toplevel| {
                        var state: [2]u32 = [_]u32{
                            @enumToInt(prot.xdg_toplevel_state.activated),
                            @enumToInt(prot.xdg_toplevel_state.resizing),
                        };

                        try prot.xdg_toplevel_send_configure(
                            xdg_toplevel.*,
                            self.newWidth(pointer_x),
                            self.newHeight(pointer_y),
                            &state);
                        try prot.xdg_surface_send_configure(xdg_surface.*, client.nextSerial());
                    }
                }
            }
        }
    }

    fn newWidth(self: Resize, pointer_x: f64) i32 {
        var direction = @intToEnum(edge, self.direction);
        var dx = switch(direction) {
            edge.bottom_right => pointer_x - self.pointer_x,
            edge.right =>        pointer_x - self.pointer_x,
            edge.top_right =>    pointer_x - self.pointer_x,
            edge.bottom_left =>  self.pointer_x - pointer_x,
            edge.left =>         self.pointer_x - pointer_x,
            edge.top_left =>     self.pointer_x - pointer_x,
            else => 0,
        };

        return self.width + @floatToInt(i32, dx);
    }

    fn newHeight(self: Resize, pointer_y: f64) i32 {
        var direction = @intToEnum(edge, self.direction);
        var dy = switch(direction) {
            edge.bottom_right => pointer_y - self.pointer_y,
            edge.bottom =>       pointer_y - self.pointer_y,
            edge.bottom_left =>  pointer_y - self.pointer_y,
            edge.top_right =>    self.pointer_y - pointer_y,
            edge.top =>          self.pointer_y - pointer_y,
            edge.top_left =>     self.pointer_y - pointer_y,
            else => 0,
        };

        return self.height + @floatToInt(i32, dy);
    }

    pub fn offsetX(self: Resize, old_buffer_width: i32, new_buffer_width: i32) i32 {
        var direction = @intToEnum(edge, self.direction);
        return switch(direction) {
            edge.bottom_left => old_buffer_width - new_buffer_width,
            edge.left =>        old_buffer_width - new_buffer_width,
            edge.top_left =>    old_buffer_width - new_buffer_width,
            else => 0,
        };
    }

    pub fn offsetY(self: Resize, old_buffer_height: i32, new_buffer_height: i32) i32 {
        var direction = @intToEnum(edge, self.direction);
        return switch(direction) {
            edge.top_right => old_buffer_height - new_buffer_height,
            edge.top =>       old_buffer_height - new_buffer_height,
            edge.top_left =>  old_buffer_height - new_buffer_height,
            else => 0,
        };
    }    
};