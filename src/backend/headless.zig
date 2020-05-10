
pub const HeadlessBackend = struct {
    const Self = @This();

    pub fn draw(self: Self) void {
    }

    pub fn shouldClose(self: Self) bool {
        return false;
    }

    pub fn newOutput(self: Self, w: i32, h: i32) HeadlessOutput {
        return HeadlessOutput {

        };
    }

    pub fn deinit(self: Self) void {
    }
};

pub fn init() !HeadlessBackend {
    return HeadlessBackend {
    };
}

pub const HeadlessOutput = struct {
    const Self = @This();

};