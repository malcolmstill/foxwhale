const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;

pub fn PoolIterable(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        pool: Pool(T, U),
        list: []Tq.Node,

        const Self = @This();

        const Tq = std.TailQueue(void);

        pub fn iterator(self: *Self, list: *Tq) Iterator {
            return Iterator{
                .pool_iterable = self,
                .node = list.first,
            };
        }

        pub const Iterator = struct {
            pool_iterable: *Self,
            node: ?*Tq.Node,

            pub fn next(self: *Iterator) ?*T {
                if (self.node) |node| {
                    defer self.node = node.next;

                    const index = self.indexOf(node);
                    const ptr = &self.pool_iterable.pool.entities[index];

                    return ptr;
                }

                return null;
            }

            fn indexOf(self: *Iterator, ptr: *Tq.Node) U {
                const start = @ptrToInt(&self.pool_iterable.list[0]);
                const end = @ptrToInt(&self.pool_iterable.list[self.pool_iterable.list.len - 1]);
                const v = @ptrToInt(ptr);

                std.debug.assert(v >= start or v <= end);

                const index = @intCast(U, (v - start) / @sizeOf(Tq.Node));

                return index;
            }
        };

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var pool = try Pool(T, U).init(allocator, count);
            errdefer pool.deinit();
            var list = try allocator.alloc(Tq.Node, count);

            return Self{
                .alloc = allocator,
                .pool = pool,
                .list = list,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.list);
            self.pool.deinit();
        }

        pub fn create(self: *Self, list: *Tq, value: T) !*T {
            const ptr = try self.pool.create(value);
            const index = self.pool.indexOf(ptr);

            std.debug.assert(index != null);
            defer list.append(&self.list[index.?]);

            return ptr;
        }

        pub fn destroy(self: *Self, list: *Tq, ptr: *T) void {
            const index = self.pool.indexOf(ptr) orelse return;

            list.remove(&self.list[index]);

            self.pool.destroy(ptr);
        }
    };
}

test {
    var p = try PoolIterable(i32, u2).init(std.testing.allocator, 3);
    defer p.deinit();

    var list = PoolIterable(i32, u2).Tq{};

    var first = try p.create(&list, 38);
    defer p.destroy(&list, first);
    var middle = try p.create(&list, 39);
    defer p.destroy(&list, middle);

    var it = p.iterator(&list);
    try std.testing.expectEqual(it.next(), first);
    try std.testing.expectEqual(it.next(), middle);
    try std.testing.expectEqual(it.next(), null);

    var last = try p.create(&list, 40);
    defer p.destroy(&list, last);

    it = p.iterator(&list);
    try std.testing.expectEqual(it.next(), first);
    try std.testing.expectEqual(it.next(), middle);
    try std.testing.expectEqual(it.next(), last);
    try std.testing.expectEqual(it.next(), null);
}
