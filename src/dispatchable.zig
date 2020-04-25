
pub const Dispatchable = struct {
    container: usize,
    impl: fn(usize) void,

    const Self = @This();

    pub fn dispatch(self: *Self) void {
        self.impl(self.container);
        // @call(.{}, self.impl, .{ self.container });
    }
};