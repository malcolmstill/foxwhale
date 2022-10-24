const std = @import("std");
const mem = std.mem;

pub fn Pool(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        entities: []T,
        free_list: []?U,
        next_free: ?U,

        const Self = @This();

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var entities = try allocator.alloc(T, count);
            var free_list = try allocator.alloc(?U, count);

            std.log.info("Allocating []{}: {} bytes (unit size {} bytes)", .{
                T,
                @sizeOf(T) * entities.len + @sizeOf(?U) * free_list.len + @sizeOf(?U) + @sizeOf(mem.Allocator),
                @sizeOf(T),
            });

            // Make every free_list node point to the next node
            for (free_list) |_, index| {
                const i = @intCast(U, index);
                if (i == free_list.len - 1) {
                    free_list[i] = null;
                } else {
                    free_list[i] = i + 1;
                }
            }

            return Self{
                .alloc = allocator,
                .entities = entities,
                .free_list = free_list,
                .next_free = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.entities);
            self.alloc.free(self.free_list);
        }

        pub fn create(self: *Self, value: T) !*T {
            const ptr = try self.createPtr();

            ptr.* = value;

            return ptr;
        }

        pub fn createPtr(self: *Self) !*T {
            if (self.next_free) |next_free| {
                defer self.next_free = self.free_list[next_free];

                return &self.entities[next_free];
            }

            return error.OutOfMemory;
        }

        pub fn destroy(self: *Self, value_ptr: *T) !void {
            const index = self.indexOf(value_ptr) orelse return error.InvalidPointer;

            self.free_list[index] = self.next_free;
            self.next_free = index;
        }

        pub fn indexOf(self: *Self, value_ptr: *T) ?U {
            const start = @ptrToInt(&self.entities[0]);
            const end = @ptrToInt(&self.entities[self.entities.len - 1]);
            const v = @ptrToInt(value_ptr);

            if (v < start or v > end) return null;

            const index = @intCast(U, (v - start) / @sizeOf(T));

            return index;
        }
    };
}

test {
    var p = try Pool(i32, u2).init(std.testing.allocator, 3);
    defer p.deinit();

    var first = try p.create(11);
    var middle = try p.create(12);
    var last = try p.create(13);

    try std.testing.expectEqual(first.*, 11);
    try std.testing.expectEqual(middle.*, 12);
    try std.testing.expectEqual(last.*, 13);

    try std.testing.expectError(error.OutOfMemory, p.create(101));

    try p.destroy(last);

    last = try p.create(21);

    try std.testing.expectError(error.OutOfMemory, p.create(102));

    try p.destroy(middle);
    _ = try p.create(31); // middle

    try std.testing.expectError(error.OutOfMemory, p.create(103));

    try p.destroy(first);
    _ = try p.create(41); // first

    try std.testing.expectEqual(first.*, 41);
    try std.testing.expectEqual(middle.*, 31);
    try std.testing.expectEqual(last.*, 21);
}
