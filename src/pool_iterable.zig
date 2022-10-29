const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;

pub fn PoolIterable(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        pool: Pool(T, U),
        nodes: []Tq.Node,

        const Self = @This();

        const Tq = std.TailQueue(void);

        pub fn iterable(self: *Self) Iterable {
            return Iterable{
                .pool_iterable = self,
                .list = Tq{},
            };
        }

        pub const Iterable = struct {
            pool_iterable: *Self,
            list: Tq,

            pub fn create(self: *Iterable, value: T) !*T {
                const ptr = try self.pool_iterable.pool.create(value);
                const index = self.pool_iterable.pool.indexOf(ptr);

                std.debug.assert(index != null);
                defer self.list.append(&self.pool_iterable.nodes[index.?]);

                return ptr;
            }

            pub fn destroy(self: *Iterable, ptr: *T) void {
                const index = self.pool_iterable.pool.indexOf(ptr) orelse return;

                self.list.remove(&self.pool_iterable.nodes[index]);

                self.pool_iterable.pool.destroy(ptr);
            }

            pub fn iterator(self: *Iterable) Iterator {
                return Iterator{
                    .iterable = self,
                    .node = self.list.first,
                };
            }

            pub const Iterator = struct {
                iterable: *Iterable,
                node: ?*Tq.Node,

                pub fn next(self: *Iterator) ?*T {
                    if (self.node) |node| {
                        defer self.node = node.next;

                        const index = self.indexOf(node);
                        const ptr = &self.iterable.pool_iterable.pool.entities[index];

                        return ptr;
                    }

                    return null;
                }

                fn indexOf(self: *Iterator, ptr: *Tq.Node) U {
                    const start = @ptrToInt(&self.iterable.pool_iterable.nodes[0]);
                    const end = @ptrToInt(&self.iterable.pool_iterable.nodes[self.iterable.pool_iterable.nodes.len - 1]);
                    const v = @ptrToInt(ptr);

                    std.debug.assert(v >= start or v <= end);

                    const index = @intCast(U, (v - start) / @sizeOf(Tq.Node));

                    return index;
                }
            };
        };

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var pool = try Pool(T, U).init(allocator, count);
            errdefer pool.deinit();
            var nodes = try allocator.alloc(Tq.Node, count);

            return Self{
                .alloc = allocator,
                .pool = pool,
                .nodes = nodes,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.nodes);
            self.pool.deinit();
        }
    };
}

test {
    var p = try PoolIterable(i32, u2).init(std.testing.allocator, 3);
    defer p.deinit();

    var list = p.iterable();

    var first = try list.create(38);
    defer list.destroy(first);
    var middle = try list.create(39);
    defer list.destroy(middle);

    var it = list.iterator();
    try std.testing.expectEqual(it.next(), first);
    try std.testing.expectEqual(it.next(), middle);
    try std.testing.expectEqual(it.next(), null);

    var last = try list.create(40);
    defer list.destroy(last);

    it = list.iterator();
    try std.testing.expectEqual(it.next(), first);
    try std.testing.expectEqual(it.next(), middle);
    try std.testing.expectEqual(it.next(), last);
    try std.testing.expectEqual(it.next(), null);
}
