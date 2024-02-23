const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Pool = @import("pool.zig").Pool;

pub fn IterablePool(comptime T: type, comptime U: type) type {
    return struct {
        alloc: mem.Allocator,
        pool: Pool(T, U),
        nodes: []Tq.Node,
        list: Tq,

        const Self = @This();

        const Tq = std.TailQueue(void);

        pub const Handle = U;

        pub fn init(allocator: mem.Allocator, count: U) !Self {
            var pool = try Pool(T, U).init(allocator, count);
            errdefer pool.deinit();
            const nodes = try allocator.alloc(Tq.Node, count);

            return Self{
                .alloc = allocator,
                .pool = pool,
                .nodes = nodes,
                .list = Tq{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.nodes);
            self.pool.deinit();
        }

        pub fn create(self: *Self, value: T) !*T {
            const ptr = try self.createPtr();

            ptr.* = value;

            return ptr;
        }

        pub fn createPtr(self: *Self) !*T {
            const ptr = try self.pool.createPtr();
            const index = self.pool.indexOf(ptr);

            std.debug.assert(index != null);
            defer self.list.append(&self.nodes[index.?]);

            return ptr;
        }

        pub fn destroy(self: *Self, ptr: *T) void {
            const index = self.pool.indexOf(ptr) orelse return;

            self.list.remove(&self.nodes[index]);

            self.pool.destroy(ptr);
        }

        pub fn indexOf(self: *Self, ptr: *T) U {
            return self.pool_iterable.pool.indexOf(ptr);
        }

        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .pool_iterable = self,
                .node = self.list.first,
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
                const start = @intFromPtr(&self.pool_iterable.nodes[0]);
                const end = @intFromPtr(&self.pool_iterable.nodes[self.pool_iterable.nodes.len - 1]);
                const v = @intFromPtr(ptr);

                std.debug.assert(v >= start or v <= end);

                const index: U = @intCast((v - start) / @sizeOf(Tq.Node));

                return index;
            }
        };
    };
}

// test {
//     var p = try IterablePool(i32, u2).init(std.testing.allocator, 3);
//     defer p.deinit();

//     var list = p.iterable();

//     var first = try list.create(38);
//     defer list.destroy(first);
//     var middle = try list.create(39);
//     defer list.destroy(middle);

//     var it = list.iterator();
//     try std.testing.expectEqual(it.next(), first);
//     try std.testing.expectEqual(it.next(), middle);
//     try std.testing.expectEqual(it.next(), null);

//     var last = try list.create(40);
//     defer list.destroy(last);

//     it = list.iterator();
//     try std.testing.expectEqual(it.next(), first);
//     try std.testing.expectEqual(it.next(), middle);
//     try std.testing.expectEqual(it.next(), last);
//     try std.testing.expectEqual(it.next(), null);
// }
