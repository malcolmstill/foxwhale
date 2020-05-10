const std = @import("std");

pub fn Stalloc(comptime B: type, comptime T: type, comptime S: usize) type {
    return struct {
        entries: [S]Entry,

        const Self = @This();

        const Entry = struct {
            in_use: bool,
            index: usize,
            belongs_to: *B,
            value: T,
        };

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

        pub fn new(self: *Self, belongs_to: *B) !*T {
            var i: usize = 0;
            while (i < S) {
                var e: *Entry = &self.entries[i];
                if (e.in_use == false) {
                    e.index = i;
                    e.in_use = true;
                    e.belongs_to = belongs_to;

                    return &e.value;
                } else {
                    i = i + 1;
                    continue;
                }
            }

            return error.StallocExhausted;
        }

        pub fn deinit(self: *Self, t: *T) void {
            var entry: *Entry = @fieldParentPtr(Entry, "value", t);
            entry.in_use = false;
        }

        pub fn releaseBelongingTo(self: *Self, b: *B) !void {
            var i: usize = 0;
            while (i < S) {
                var entry: *Entry = &self.entries[i];
                if (entry.in_use and entry.belongs_to == b) {
                    entry.in_use = false;
                    entry.value.deinit() catch |err| {
                        if (std.builtin.mode == std.builtin.Mode.Debug) {
                            return err;
                        } else {
                            std.debug.warn("warning: error in releaseBelongingTo\n", .{});
                        }
                    };
                }
                i = i + 1;
            }
        }

        pub fn freeCount(self: *Self) usize {
            var i: usize = 0;
            var count: usize = 0;
            while (i < S) {
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

const TestClient = struct {
    i: u32,
};

const Payload = struct {
    data: i32,

    pub fn deinit(self: *Payload) !void {
        self.data = 0;
    }
};

var memory: Stalloc(TestClient, Payload, 4) = undefined;

test "stalloc test" {
    var test_client_1 = TestClient {
        .i = 1,
    };

    var test_client_2 = TestClient {
        .i = 2,
    };    

    std.debug.assert(memory.freeCount() == 4);

    var x1 = try memory.new(&test_client_1);
    std.debug.assert(memory.freeCount() == 3);

    var x2 = try memory.new(&test_client_1);
    std.debug.assert(memory.freeCount() == 2);

    var x3 = try memory.new(&test_client_2);
    std.debug.assert(memory.freeCount() == 1);

    var x4 = try memory.new(&test_client_2);
    std.debug.assert(memory.freeCount() == 0);

    memory.deinit(x1);
    std.debug.assert(memory.freeCount() == 1);

    x1 = try memory.new(&test_client_1);
    std.debug.assert(memory.freeCount() == 0);

    var a: anyerror!*Payload = memory.new(&test_client_1);
    if (a) |_| {} else |err| {
        std.debug.assert(err == error.StallocExhausted);
    }

    try memory.releaseBelongingTo(&test_client_1);
    std.debug.assert(memory.freeCount() == 2);
}