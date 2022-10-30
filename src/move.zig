// Move Zig! Move Zig! Move Zig! Move Zig! You know what you doing?
// Take off every Zig!

const Window = @import("resource/window.zig").Window;

pub const Move = struct {
    window: *Window,
    window_x: i32, // saved Window x
    window_y: i32, // saved Window y
    pointer_x: f64, // saved pointer x
    pointer_y: f64, // saved pointer y
};
