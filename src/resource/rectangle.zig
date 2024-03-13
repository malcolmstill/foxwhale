pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn init(x: i32, y: i32, width: i32, height: i32) Rectangle {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
};
