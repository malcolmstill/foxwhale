pub const HeadlessBackend = struct {
    const Self = @This();

    pub fn init(_: *Self) !void {}

    pub fn newOutput(_: *Self, _: i32, _: i32) !HeadlessOutput {
        return HeadlessOutput{};
    }

    pub fn deinit(_: Self) void {}
};

pub fn new() !HeadlessBackend {
    return HeadlessBackend{};
}

pub const HeadlessOutput = struct {
    const Self = @This();

    pub fn begin(_: Self) void {}

    pub fn end(_: Self) void {}

    pub fn swap(_: Self) void {}

    pub fn getWidth(_: Self) i32 {
        return 0;
    }

    pub fn getHeight(_: Self) i32 {
        return 0;
    }

    pub fn shouldClose(_: Self) bool {
        return false;
    }

    pub fn deinit(_: *Self) void {}
};
