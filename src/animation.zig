const std = @import("std");
const mem = std.mem;
const math = std.math;
const time = std.time;
const easing = @import("ease.zig");
const ArrayList = std.ArrayList;

pub fn Animation(comptime Targets: type) type {
    const AnimationType = enum {
        property,
        sequential,
        parallel,
    };

    return union(AnimationType) {
        property: Property,
        sequential: Sequential,
        parallel: Parallel,

        const Self = @This();

        pub fn start(self: *Self) void {
            switch (self.*) {
                .property => |*p| p.start(),
                .sequential => |*s| s.start(),
                .parallel => |*p| p.start(),
            }
        }

        pub fn update(self: *Self, t: f64) bool {
            return switch (self.*) {
                .property => |*p| p.update(t),
                .sequential => |*s| s.update(t),
                .parallel => |*p| p.update(t),
            };
        }

        pub fn deinit(self: *Self) void {
            switch (self.*) {
                .property => {},
                .sequential => |*s| s.deinit(),
                .parallel => |*p| p.deinit(),
            }
        }

        pub const Property = struct {
            initial_value: f32,
            final_value: f32,
            start_time: f64 = 0.0,
            duration: f64,
            easing: *const fn (f64) f64,
            property: []const u8,
            target: Targets,

            pub fn start(self: *Property) void {
                self.start_time = now();
            }

            pub fn update(self: *Property, t: f64) bool {
                if (t < self.start_time) return false;

                if (self.duration <= 0.0 or t > self.start_time + self.duration) {
                    self.set(self.final_value);
                    return true;
                }

                const progress = self.easing((t - self.start_time) / self.duration);
                const new_value = self.initial_value + (self.final_value - self.initial_value) * math.lossyCast(f32, progress);

                self.set(new_value);

                return false;
            }

            fn set(self: *Property, value: f32) void {
                const info = @typeInfo(@TypeOf(@field(self.target, @tagName(self.target))));
                inline for (@typeInfo(info.Pointer.child).Struct.fields) |field| {
                    if (field.field_type != f32) continue;
                    if (mem.eql(u8, self.property, field.name)) {
                        @field(@field(self.target, @tagName(self.target)), field.name) = value;
                    }
                }
            }
        };

        pub const Sequential = struct {
            alloc: mem.Allocator,
            animations: ArrayList(Self),
            current: usize = 0,

            pub fn init(allocator: mem.Allocator) Sequential {
                return Sequential{
                    .alloc = allocator,
                    .animations = ArrayList(Self).init(allocator),
                };
            }

            pub fn deinit(self: *Sequential) void {
                for (self.animations.items) |*a| {
                    a.deinit();
                }

                self.animations.deinit();
            }

            pub fn start(self: *Sequential) void {
                if (self.animations.items.len == 0) return;
                self.animations.items[0].start();
            }

            pub fn addParallel(self: *Sequential) !*Parallel {
                var a = Parallel.init(self.alloc);
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType{ .parallel = a };
                return &(a_ptr.*.parallel);
            }

            pub fn addSequential(self: *Sequential) !*Sequential {
                var a = Sequential.init(self.alloc);
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType{ .sequential = a };
                return &(a_ptr.*.sequential);
            }

            pub fn addProperty(self: *Sequential, a: Property) !void {
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType.Animation{ .property = a };
            }

            pub fn update(self: *Sequential, t: f64) bool {
                const current_finished = self.animations.items[self.current].update(t);

                if (current_finished == false) return false;

                if (self.current == self.animations.items.len - 1) return true;

                self.current += 1;
                self.animations.items[self.current].start();

                return false;
            }
        };

        pub const Parallel = struct {
            alloc: *mem.Allocator,
            animations: ArrayList(Self),

            pub fn init(allocator: *mem.Allocator) Parallel {
                return Parallel{
                    .alloc = allocator,
                    .animations = ArrayList(Self).init(allocator),
                };
            }

            pub fn deinit(self: *Parallel) void {
                for (self.animations.items) |*a| {
                    a.deinit();
                }

                self.animations.deinit();
            }

            pub fn start(self: *Parallel) void {
                for (self.animations.items) |*a| {
                    a.start();
                }
            }

            pub fn addParallel(self: *Parallel) !*Parallel {
                var a = Parallel.init(self.alloc);
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType{ .parallel = a };
                return &(a_ptr.*.parallel);
            }

            pub fn addSequential(self: *Parallel) !*Sequential {
                var a = Sequential.init(self.alloc);
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType{ .sequential = a };
                return &(a_ptr.*.sequential);
            }

            pub fn addProperty(self: *Parallel, a: Property) !void {
                const a_ptr = try self.animations.addOne();
                a_ptr.* = AnimationType{ .property = a };
            }

            pub fn update(self: *Parallel, t: f64) bool {
                var finished = true;

                for (self.animations.items) |*a| {
                    const sub_finished = a.update(t);
                    finished = finished and sub_finished;
                }

                return finished;
            }
        };
    };
}

const testing = std.testing;

test "Sequential Animations" {
    var allocator = testing.allocator;

    const Point = struct {
        x: f32,
        y: f32,
    };

    const AnimatableType = enum {
        point,
    };

    const Animatable = union(AnimatableType) {
        point: *Point,
    };

    const Anim = Animation(Animatable);

    var pt = Point{
        .x = 80.0,
        .y = 100.0,
    };

    const x = Animatable{ .point = &pt };

    var seq = Anim.Sequential.init(allocator);
    defer seq.deinit();

    try seq.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 10.0,
        .final_value = 20.0,
        .easing = easing.easeInOutSine,
        .duration = 0.125,
        .property = "x",
        .target = x,
    } });

    try seq.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 50.0,
        .final_value = 0.0,
        .easing = easing.easeInOutSine,
        .duration = 0.125,
        .property = "y",
        .target = x,
    } });

    seq.start();
    while (!seq.update(now())) {
        time.sleep(16_000_000);
    }

    try testing.expectEqual(pt.x, 20.0);
    try testing.expectEqual(pt.y, 0.0);
}

test "Parallel Animations" {
    var allocator = testing.allocator;

    const Point = struct {
        x: f32,
        y: f32,
    };

    const AnimatableType = enum {
        point,
    };

    const Animatable = union(AnimatableType) {
        point: *Point,
    };

    const Anim = Animation(Animatable);

    var pt = Point{
        .x = 80.0,
        .y = 100.0,
    };

    const x = Animatable{ .point = &pt };

    var par = Anim.Parallel.init(allocator);
    defer par.deinit();

    try par.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 10.0,
        .final_value = 20.0,
        .easing = easing.easeInOutSine,
        .duration = 0.125,
        .property = "x",
        .target = x,
    } });

    try par.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 50.0,
        .final_value = 0.0,
        .easing = easing.easeInOutSine,
        .duration = 0.125,
        .property = "y",
        .target = x,
    } });

    par.start();
    while (!par.update(now())) {
        time.sleep(16_000_000);
    }

    try testing.expectEqual(pt.x, 20.0);
    try testing.expectEqual(pt.y, 0.0);
}

// seconds
pub fn now() f64 {
    return @intToFloat(f64, time.nanoTimestamp()) / 1_000_000_000.0;
}
