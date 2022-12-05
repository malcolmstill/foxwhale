const std = @import("std");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;
const Backend = @import("backend.zig").Backend;
const Output = @import("backend.zig").Output;
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

const Interfacekit = struct {
    backends: Pool(Backend, u8),
    outputs: Pool(Output, u8),

    pub fn init(alloc: mem.Allocator) !Interfacekit {
        return Interfacekit{
            .backends = try Pool(Backend).init(alloc, 16),
            .outputs = try Pool(Output).init(alloc, 64),
        };
    }

    pub fn deinit(self: *Interfacekit) void {
        self.outputs.deinit();
        self.backends.deinit();
    }

    pub fn defaultBackend() void {}
};

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
