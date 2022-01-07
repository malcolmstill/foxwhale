const std = @import("std");
const cursor = @embedFile("../assets/cursor.data");
const Renderer = @import("renderer.zig").Renderer;
const compositor = @import("compositor.zig");
const Window = @import("window.zig").Window;
const Mat4x4 = @import("math.zig").Mat4x4;

pub const Cursor = struct {
    texture: ?u32,
    width: i32,
    height: i32,

    pub fn init() !Cursor {
        var texture = try Renderer.makeTexture(32, 32, 32 * 4, 0, cursor[0..]);

        return Cursor{
            .width = 32,
            .height = 32,
            .texture = texture,
        };
    }

    pub fn deinit(self: *Cursor) void {
        if (self.texture) |texture| {
            Renderer.releaseTexture(texture) catch |err| {};
        }
    }

    pub fn render(self: *Cursor, output_width: i32, output_height: i32, renderer: *Renderer, x: i32, y: i32) !void {
        if (compositor.COMPOSITOR.client_cursor) |client_cursor| {
            switch (client_cursor) {
                .CursorWindow => |client_cursor_window| {
                    try client_cursor_window.render(output_width, output_height, renderer, x, y);
                    return;
                },
                .CursorHidden => return,
            }
        }

        const texture = self.texture orelse return;
        const program = try renderer.useProgram("window");
        try Renderer.setUniformFloat(program, "opacity", 1.0);
        try Renderer.setUniformMatrix(program, "scale", Mat4x4(f32).scale([_]f32{ 1.0, 1.0, 1.0, 1.0 }).data);
        try Renderer.setUniformMatrix(program, "translate", Mat4x4(f32).translate([_]f32{ @intToFloat(f32, x), @intToFloat(f32, y), 0.0, 1.0 }).data);
        try Renderer.setUniformMatrix(program, "origin", Mat4x4(f32).identity().data);
        try Renderer.setUniformMatrix(program, "originInverse", Mat4x4(f32).identity().data);
        try renderer.renderSurface(output_width, output_height, program, texture, self.width, self.height);
    }
};

pub const ClientCursorType = enum {
    CursorWindow,
    CursorHidden,
};

pub const ClientCursor = union(ClientCursorType) {
    CursorWindow: *Window,
    CursorHidden,
};
