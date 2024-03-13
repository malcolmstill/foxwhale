// Move Zig! Move Zig! Move Zig! Move Zig! You know what you doing?
// Take off every Zig!

const Window = @import("resource/window.zig").Window;

pub const Move = struct {
    window: *Window,
    window_x: i32, // saved Window x
    window_y: i32, // saved Window y
    pointer_x: f64, // saved pointer x
    pointer_y: f64, // saved pointer y

    pub fn init(window: *Window, window_x: i32, window_y: i32, pointer_x: f64, pointer_y: f64) Move {
        return Move{
            .window = window,
            .window_x = window_x,
            .window_y = window_y,
            .pointer_x = pointer_x,
            .pointer_y = pointer_y,
        };
    }
};
