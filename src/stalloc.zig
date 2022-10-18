const std = @import("std");
const mem = std.mem;

pub fn StaticArray(comptime T: type) type {
    return struct {
        alloc: mem.Allocator,
        entries: []Entry,
        size: usize,

        const Self = @This();

        const Entry = struct {
            in_use: bool,
            index: usize,
            value: T = undefined,
        };

        pub fn init(alloc: mem.Allocator, size: usize) !Self {
            var entries = try alloc.alloc(Entry, size);

            for (entries) |_, i| {
                entries[i] = Entry{
                    .in_use = false,
                    .index = i,
                };
            }

            return Self{
                .size = size,
                .alloc = alloc,
                .entries = entries,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.entries);
        }

        pub const Iterator = struct {
            stalloc: *Self,
            index: usize,

            pub fn next(it: *Iterator) ?*T {
                while (it.index < it.stalloc.entries.len) {
                    var entry: *Entry = &it.stalloc.entries[it.index];
                    if (entry.in_use) {
                        it.index += 1;
                        return &entry.value;
                    }
                    it.index += 1;
                }
                return null;
            }

            pub fn reset(it: *Iterator) void {
                it.index = 0;
            }
        };

        pub fn create(self: *Self) !*T {
            var i: usize = 0;
            while (i < self.size) {
                var e: *Entry = &self.entries[i];
                if (e.in_use == false) {
                    e.index = i;
                    e.in_use = true;

                    return &e.value;
                } else {
                    i = i + 1;
                    continue;
                }
            }

            return error.StallocExhausted;
        }

        pub fn destroy(_: *Self, t: *T) usize {
            var entry: *Entry = @fieldParentPtr(Entry, "value", t);
            entry.in_use = false;
            return entry.index;
        }

        pub fn getAtIndex(self: *Self, index: usize) ?*T {
            if (index < 0 and index >= self.size) {
                return null;
            }

            if (self.entries[index].in_use == false) {
                return null;
            }

            var e: *Entry = &self.entries[index];
            return &e.value;
        }

        // TODO: is this safe?
        pub fn getIndexOf(_: *Self, t: *T) usize {
            var entry: *Entry = @fieldParentPtr(Entry, "value", t);
            return entry.index;
        }

        pub fn freeCount(self: *Self) usize {
            var i: usize = 0;
            var count: usize = 0;
            while (i < self.size) {
                var entry: *Entry = &self.entries[i];
                if (!entry.in_use) {
                    count += 1;
                }
                i += 1;
            }

            return count;
        }

        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .stalloc = self,
                .index = 0,
            };
        }
    };
}

// const TestClient = struct {
//     i: u32,
// };

// const Payload = struct {
//     data: i32,

//     pub fn deinit(self: *Payload) !void {
//         self.data = 0;
//     }
// };

// var memory: Stalloc(TestClient, Payload, 4) = undefined;

// test "stalloc test" {
//     var test_client_1 = TestClient{
//         .i = 1,
//     };

//     var test_client_2 = TestClient{
//         .i = 2,
//     };

//     std.debug.assert(memory.freeCount() == 4);

//     var x1 = try memory.new(&test_client_1);
//     std.debug.assert(memory.freeCount() == 3);

//     _ = try memory.new(&test_client_1);
//     std.debug.assert(memory.freeCount() == 2);

//     _ = try memory.new(&test_client_2);
//     std.debug.assert(memory.freeCount() == 1);

//     _ = try memory.new(&test_client_2);
//     std.debug.assert(memory.freeCount() == 0);

//     memory.deinit(x1);
//     std.debug.assert(memory.freeCount() == 1);

//     x1 = try memory.new(&test_client_1);
//     std.debug.assert(memory.freeCount() == 0);

//     var a: anyerror!*Payload = memory.new(&test_client_1);
//     if (a) |_| {} else |err| {
//         std.debug.assert(err == error.StallocExhausted);
//     }

//     try memory.releaseBelongingTo(&test_client_1);
//     std.debug.assert(memory.freeCount() == 2);
// }
