
pub const HeadlessBackend = struct {
    const Self = @This();

    pub fn newOutput(self: *Self, w: i32, h: i32) !HeadlessOutput {
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

    pub fn begin(self: Self) void {
    }

    pub fn swap(self: Self) void {
    }

    pub fn getWidth(self: Self) i32 {
        return 0;
    }

    pub fn getHeight(self: Self) i32 {
        return 0;
    }

    pub fn shouldClose(self: Self) bool {
        return false;
    }

    pub fn deinit(self: *Self) void {
    }
};