const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

pub fn Pool(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        entities: []T,
        free_stack: []?U,
        next_free: ?U,
        count: usize = 0,
        in_use: if (builtin.mode == .Debug) []bool else void,

        const Self = @This();

        pub const Handle = U;

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            const entities = try allocator.alloc(T, count);
            var free_stack = try allocator.alloc(?U, count);
            var in_use: (if (builtin.mode == .Debug) []bool else void) = if (builtin.mode == .Debug) try allocator.alloc(bool, count) else undefined;

            std.log.info("Allocating [{}]{}: {} bytes (unit size {} bytes)", .{
                count,
                T,
                @sizeOf(T) * entities.len + @sizeOf(?U) * free_stack.len + @sizeOf(?U) + @sizeOf(mem.Allocator),
                @sizeOf(T),
            });

            // Make every free_stack node point to the next node
            for (free_stack, 0..) |_, index| {
                if (builtin.mode == .Debug) in_use[index] = false;
                free_stack[index] = @as(U, @intCast(index)) + 1;
            }
            free_stack[free_stack.len - 1] = null;

            return .{
                .alloc = allocator,
                .entities = entities,
                .free_stack = free_stack,
                .next_free = 0,
                .in_use = in_use,
            };
        }

        pub fn deinit(pool: *Self) void {
            if (builtin.mode == .Debug) {
                for (pool.in_use, 0..) |in_use, i| {
                    if (in_use) {
                        std.debug.print("Pool: leaked item {} in [{}]{}\n", .{ i, pool.entities.len, T });
                    }
                }
            }

            pool.alloc.free(pool.entities);
            pool.alloc.free(pool.free_stack);
            if (builtin.mode == .Debug) pool.alloc.free(pool.in_use);
        }

        pub fn create(pool: *Self, value: T) !*T {
            const ptr = try pool.createPtr();

            ptr.* = value;

            return ptr;
        }

        pub fn createPtr(pool: *Self) !*T {
            if (pool.next_free) |next_free| {
                defer pool.next_free = pool.free_stack[next_free];

                if (builtin.mode == .Debug) pool.in_use[next_free] = true;
                pool.count += 1;
                return &pool.entities[next_free];
            }

            return error.OutOfMemory;
        }

        pub fn destroy(pool: *Self, ptr: *T) void {
            const index = pool.indexOf(ptr) orelse return;

            pool.count -= 1;
            if (builtin.mode == .Debug) pool.in_use[index] = false;

            pool.free_stack[index] = pool.next_free;
            pool.next_free = index;
        }

        pub fn indexOf(pool: *Self, ptr: *T) ?U {
            const start = @intFromPtr(&pool.entities[0]);
            const end = @intFromPtr(&pool.entities[pool.entities.len - 1]);
            const v = @intFromPtr(ptr);

            if (v < start or v > end) return null;

            const index = @as(U, @intCast((v - start) / @sizeOf(T)));

            return index;
        }
    };
}

test {
    var p = try Pool(i32, u2).init(std.testing.allocator, 3);
    defer p.deinit();

    const first = try p.create(11);
    const middle = try p.create(12);
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
