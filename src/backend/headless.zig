
pub const HeadlessBackend = struct {
    const Self = @This();

    pub fn draw(self: Self) void {
    }

    pub fn wait(self: Self) i32 {
        return -1;
    }

    pub fn shouldClose(self: Self) bool {
        return false;
    }

    pub fn deinit(self: Self) void {
    }
};

pub fn init() !HeadlessBackend {
    return HeadlessBackend {
    };
}