const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;

pub fn SubsetPool(comptime T: type, comptime U: type) type {
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

            const nodes = try allocator.alloc(Tq.Node, count);
            const global_nodes = try allocator.alloc(Tq.Node, count);

            return .{
                .alloc = allocator,
                .pool = pool,
                .nodes = nodes,
                .global_nodes = global_nodes,
                .global_list = Tq{},
            };
        }

        pub fn deinit(subset_pool: *Self) void {
            subset_pool.alloc.free(subset_pool.nodes);
            subset_pool.alloc.free(subset_pool.global_nodes);
            subset_pool.pool.deinit();
        }

        pub fn initSubset(subset_pool: *Self) Subset {
            return .{
                .subset_pool = subset_pool,
                .list = Tq{},
            };
        }

        pub const Subset = struct {
            subset_pool: *Self,
            list: Tq,

            pub fn deinit(subset: *Subset) void {
                var it = subset.iterator();

                while (it.next()) |n| {
                    subset.destroy(n);
                }
            }

            pub fn create(subset: *Subset, value: T) !*T {
                // Allocate from the underlying pool
                const ptr = try subset.subset_pool.pool.create(value);
                const index = subset.subset_pool.pool.indexOf(ptr);

                std.debug.assert(index != null);

                defer subset.list.append(&subset.subset_pool.nodes[index.?]);
                defer subset.subset_pool.global_list.append(&subset.subset_pool.global_nodes[index.?]);

                return ptr;
            }

            pub fn createPtr(subset: *Subset) !*T {
                const ptr = try subset.subset_pool.pool.createPtr();
                const index = subset.subset_pool.pool.indexOf(ptr);

                std.debug.assert(index != null);
                defer subset.list.append(&subset.subset_pool.nodes[index.?]);
                defer subset.subset_pool.global_list.append(&subset.subset_pool.global_nodes[index.?]);

                return ptr;
            }

            pub fn destroy(subset: *Subset, ptr: *T) void {
                const index = subset.subset_pool.pool.indexOf(ptr) orelse return;

                subset.list.remove(&subset.subset_pool.nodes[index]);
                subset.subset_pool.global_list.remove(&subset.subset_pool.global_nodes[index]);

                subset.subset_pool.pool.destroy(ptr);
            }

            pub fn indexOf(subset: *Subset, ptr: *T) U {
                return subset.subset_pool.pool.indexOf(ptr);
            }

            // Iterate over values in this particular subset
            pub fn iterator(subset: *Subset) SubsetIterator {
                return .{
                    .subset = subset,
                    .node = subset.list.first,
                };
            }

            pub const SubsetIterator = struct {
                subset: *Subset,
                node: ?*Tq.Node,

                pub fn next(it: *SubsetIterator) ?*T {
                    if (it.node) |node| {
                        defer it.node = node.next;

                        const index = it.indexOf(node);
                        const ptr = &it.subset.subset_pool.pool.entities[index];

                        return ptr;
                    }

                    return null;
                }

                fn indexOf(it: *SubsetIterator, ptr: *Tq.Node) U {
                    const start = @intFromPtr(&it.subset.subset_pool.nodes[0]);
                    const end = @intFromPtr(&it.subset.subset_pool.nodes[it.subset.subset_pool.nodes.len - 1]);
                    const v = @intFromPtr(ptr);

                    std.debug.assert(v >= start or v <= end);

                    const index: U = @intCast((v - start) / @sizeOf(Tq.Node));

                    return index;
                }
            };
        };

        pub fn iterator(subset_pool: *Self) Iterator {
            return Iterator{
                .subset_pool = subset_pool,
                .node = subset_pool.global_list.first,
            };
        }

        pub const Iterator = struct {
            subset_pool: *Self,
            node: ?*Tq.Node,

            pub fn next(it: *Iterator) ?*T {
                if (it.node) |node| {
                    defer it.node = node.next;

                    const index = it.indexOf(node);
                    const ptr = &it.subset_pool.pool.entities[index];

                    return ptr;
                }

                return null;
            }

            fn indexOf(it: *Iterator, ptr: *Tq.Node) U {
                const start = @intFromPtr(&it.subset_pool.global_nodes[0]);
                const end = @intFromPtr(&it.subset_pool.global_nodes[it.subset_pool.global_nodes.len - 1]);
                const v = @intFromPtr(ptr);

                std.debug.assert(v >= start or v <= end);

                const index: U = @intCast((v - start) / @sizeOf(Tq.Node));

                return index;
            }
        };
    };
}

test {
    var p = try SubsetPool(i32, u3).init(std.testing.allocator, 6);
    defer p.deinit();

    var subset1 = p.initSubset();
    defer subset1.deinit();
    var subset2 = p.initSubset();
    defer subset2.deinit();

    const subset1_1 = try subset1.create(11);
    const subset1_2 = try subset1.create(12);
    const subset1_3 = try subset1.create(12);

    const subset2_1 = try subset2.create(21);
    const subset2_2 = try subset2.create(22);
    const subset2_3 = try subset2.create(22);

    {
        var it = subset1.iterator();
        try std.testing.expectEqual(it.next(), subset1_1);
        try std.testing.expectEqual(it.next(), subset1_2);
        try std.testing.expectEqual(it.next(), subset1_3);
        try std.testing.expectEqual(it.next(), null);
    }

    {
        var it = subset2.iterator();
        try std.testing.expectEqual(it.next(), subset2_1);
        try std.testing.expectEqual(it.next(), subset2_2);
        try std.testing.expectEqual(it.next(), subset2_3);
        try std.testing.expectEqual(it.next(), null);
    }

    subset1.destroy(subset1_1);
    {
        var it = subset1.iterator();
        try std.testing.expectEqual(it.next(), subset1_2);
        try std.testing.expectEqual(it.next(), subset1_3);
        try std.testing.expectEqual(it.next(), null);
    }

    {
        var it = subset2.iterator();
        try std.testing.expectEqual(it.next(), subset2_1);
        try std.testing.expectEqual(it.next(), subset2_2);
        try std.testing.expectEqual(it.next(), subset2_3);
        try std.testing.expectEqual(it.next(), null);
    }
}
