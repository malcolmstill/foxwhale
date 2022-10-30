const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;

pub fn PoolIterable(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        pool: Pool(T, U),
        nodes: []Tq.Node,
        global_nodes: []Tq.Node,
        global_list: Tq,

        const Self = @This();

        const Tq = std.TailQueue(void);

        pub const Handle = U;

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var pool = try Pool(T, U).init(allocator, count);
            errdefer pool.deinit();
            var nodes = try allocator.alloc(Tq.Node, count);
            var global_nodes = try allocator.alloc(Tq.Node, count);

            return Self{
                .alloc = allocator,
                .pool = pool,
                .nodes = nodes,
                .global_nodes = global_nodes,
                .global_list = Tq{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.nodes);
            self.alloc.free(self.global_nodes);
            self.pool.deinit();
        }

        pub fn subset(self: *Self) Subset {
            return Subset{
                .pool_iterable = self,
                .list = Tq{},
            };
        }

        pub const Subset = struct {
            pool_iterable: *Self,
            list: Tq,

            pub fn deinit(self: *Subset) void {
                var it = self.iterator();

                while (it.next()) |n| {
                    self.destroy(n);
                }
            }

            pub fn create(self: *Subset, value: T) !*T {
                const ptr = try self.pool_iterable.pool.create(value);
                const index = self.pool_iterable.pool.indexOf(ptr);

                std.debug.assert(index != null);
                defer self.list.append(&self.pool_iterable.nodes[index.?]);
                defer self.pool_iterable.global_list.append(&self.pool_iterable.global_nodes[index.?]);

                return ptr;
            }

            pub fn destroy(self: *Subset, ptr: *T) void {
                const index = self.pool_iterable.pool.indexOf(ptr) orelse return;

                self.list.remove(&self.pool_iterable.nodes[index]);
                self.pool_iterable.global_list.remove(&self.pool_iterable.global_nodes[index]);

                self.pool_iterable.pool.destroy(ptr);
            }

            pub fn indexOf(self: *Subset, ptr: *T) U {
                return self.pool_iterable.pool.indexOf(ptr);
            }

            pub fn iterator(self: *Subset) SubsetIterator {
                return SubsetIterator{
                    .subset = self,
                    .node = self.list.first,
                };
            }

            pub const SubsetIterator = struct {
                subset: *Subset,
                node: ?*Tq.Node,

                pub fn next(self: *SubsetIterator) ?*T {
                    if (self.node) |node| {
                        defer self.node = node.next;

                        const index = self.indexOf(node);
                        const ptr = &self.subset.pool_iterable.pool.entities[index];

                        return ptr;
                    }

                    return null;
                }

                fn indexOf(self: *SubsetIterator, ptr: *Tq.Node) U {
                    const start = @ptrToInt(&self.subset.pool_iterable.nodes[0]);
                    const end = @ptrToInt(&self.subset.pool_iterable.nodes[self.subset.pool_iterable.nodes.len - 1]);
                    const v = @ptrToInt(ptr);

                    std.debug.assert(v >= start or v <= end);

                    const index = @intCast(U, (v - start) / @sizeOf(Tq.Node));

                    return index;
                }
            };
        };

        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .pool_iterable = self,
                .node = self.global_list.first,
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
                const start = @ptrToInt(&self.pool_iterable.global_nodes[0]);
                const end = @ptrToInt(&self.pool_iterable.global_nodes[self.pool_iterable.global_nodes.len - 1]);
                const v = @ptrToInt(ptr);

                std.debug.assert(v >= start or v <= end);

                const index = @intCast(U, (v - start) / @sizeOf(Tq.Node));

                return index;
            }
        };
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
