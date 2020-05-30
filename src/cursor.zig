
var cursor = @embedFile("../assets/cursor.data");
const renderer = @import("renderer.zig");
const compositor = @import("compositor.zig");
const Window = @import("window.zig").Window;

pub const Cursor = struct {
    texture: ?u32,
    width: i32,
    height: i32,

    pub fn init() !Cursor {
        var texture = try renderer.makeTexture(32, 32, 32 * 4, 0, cursor[0..]);

        return Cursor {
            .width = 32,
            .height = 32,
            .texture = texture,
        };
    }

    pub fn render(self: *Cursor, x: i32, y: i32) !void {
        if (self.texture) |texture| {
            try renderer.scale(1.0, 1.0);
            try renderer.translate(@intToFloat(f32, x), @intToFloat(f32, y));
            try renderer.setUniformMatrix(renderer.PROGRAM, "origin", renderer.identity);
            try renderer.setUniformMatrix(renderer.PROGRAM, "originInverse", renderer.identity);
            try renderer.setUniformFloat(renderer.PROGRAM, "opacity", 1.0);
            renderer.setGeometry(self.width, self.height);
            try renderer.renderSurface(renderer.PROGRAM, texture);
        }        
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