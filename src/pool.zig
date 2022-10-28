const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

pub fn Pool(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        entities: []T,
        free_list: []?U,
        next_free: ?U,
        in_use: if (builtin.mode == .Debug) []bool else void,

        const Self = @This();

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var entities = try allocator.alloc(T, count);
            var free_list = try allocator.alloc(?U, count);
            var in_use: []bool = if (builtin.mode == .Debug) try allocator.alloc(bool, count) else undefined;

            std.log.info("Allocating []{}: {} bytes (unit size {} bytes)", .{
                T,
                @sizeOf(T) * entities.len + @sizeOf(?U) * free_list.len + @sizeOf(?U) + @sizeOf(mem.Allocator),
                @sizeOf(T),
            });

            // Make every free_list node point to the next node
            for (free_list) |_, index| {
                if (builtin.mode == .Debug) in_use[index] = false;
                free_list[index] = @intCast(U, index) + 1;
            }
            free_list[free_list.len - 1] = null;

            return Self{
                .alloc = allocator,
                .entities = entities,
                .free_list = free_list,
                .next_free = 0,
                .in_use = in_use,
            };
        }

        pub fn deinit(self: *Self) void {
            if (builtin.mode == .Debug) {
                for (self.in_use) |in_use, i| {
                    if (in_use) {
                        std.debug.print("Pool: leaked item {} in [{}]{}\n", .{ i, self.entities.len, T });
                    }
                }
            }

            self.alloc.free(self.entities);
            self.alloc.free(self.free_list);
            if (builtin.mode == .Debug) self.alloc.free(self.in_use);
        }

        pub fn create(self: *Self, value: T) !*T {
            const ptr = try self.createPtr();

            ptr.* = value;

            return ptr;
        }

        pub fn createPtr(self: *Self) !*T {
            if (self.next_free) |next_free| {
                defer self.next_free = self.free_list[next_free];

                if (builtin.mode == .Debug) self.in_use[next_free] = true;

                return &self.entities[next_free];
            }

            return error.OutOfMemory;
        }

        pub fn destroy(self: *Self, value_ptr: *T) void {
            const index = self.indexOf(value_ptr) orelse return;

            if (builtin.mode == .Debug) self.in_use[index] = false;

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

    p.destroy(last);

    last = try p.create(21);

    try std.testing.expectError(error.OutOfMemory, p.create(102));

    p.destroy(middle);
    _ = try p.create(31); // middle

    try std.testing.expectError(error.OutOfMemory, p.create(103));

    p.destroy(first);
    _ = try p.create(41); // first

    try std.testing.expectEqual(first.*, 41);
    try std.testing.expectEqual(middle.*, 31);
    try std.testing.expectEqual(last.*, 21);

    p.destroy(first);
    p.destroy(middle);
    p.destroy(last);
}
