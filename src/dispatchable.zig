
pub const Dispatchable = struct {
    container: usize,
    impl: fn(usize, usize) void,

    const Self = @This();

    pub fn dispatch(self: *Self, event_type: usize) void {
        self.impl(self.container, event_type);
    }
};