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

        pub fn start(animation: *Self) void {
            switch (animation.*) {
                .property => |*p| p.start(),
                .sequential => |*s| s.start(),
                .parallel => |*p| p.start(),
            }
        }

        pub fn update(animation: *Self, t: f64) bool {
            return switch (animation.*) {
                .property => |*p| p.update(t),
                .sequential => |*s| s.update(t),
                .parallel => |*p| p.update(t),
            };
        }

        pub fn deinit(animation: *Self) void {
            switch (animation.*) {
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

            pub fn start(property: *Property) void {
                property.start_time = now();
            }

            pub fn update(property: *Property, t: f64) bool {
                if (t < property.start_time) return false;

                if (property.duration <= 0.0 or t > property.start_time + property.duration) {
                    property.set(property.final_value);
                    return true;
                }

                const progress = property.easing((t - property.start_time) / property.duration);
                const new_value = property.initial_value + (property.final_value - property.initial_value) * math.lossyCast(f32, progress);

                property.set(new_value);

                return false;
            }

            fn set(property: *Property, value: f32) void {
                const info = @typeInfo(@TypeOf(@field(property.target, @tagName(property.target))));
                inline for (@typeInfo(info.Pointer.child).Struct.fields) |field| {
                    if (field.field_type != f32) continue;
                    if (mem.eql(u8, property.property, field.name)) {
                        @field(@field(property.target, @tagName(property.target)), field.name) = value;
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

            pub fn deinit(sequential: *Sequential) void {
                for (sequential.animations.items) |*a| {
                    a.deinit();
                }

                sequential.animations.deinit();
            }

            pub fn start(sequential: *Sequential) void {
                if (sequential.animations.items.len == 0) return;
                sequential.animations.items[0].start();
            }

            pub fn addParallel(sequential: *Sequential) !*Parallel {
                const a = Parallel.init(sequential.alloc);
                const a_ptr = try sequential.animations.addOne();
                a_ptr.* = AnimationType{ .parallel = a };
                return &(a_ptr.*.parallel);
            }

            pub fn addSequential(sequential: *Sequential) !*Sequential {
                const a = Sequential.init(sequential.alloc);
                const a_ptr = try sequential.animations.addOne();
                a_ptr.* = AnimationType{ .sequential = a };
                return &(a_ptr.*.sequential);
            }

            pub fn addProperty(sequential: *Sequential, a: Property) !void {
                const a_ptr = try sequential.animations.addOne();
                a_ptr.* = AnimationType{ .property = a };
            }

            pub fn update(sequential: *Sequential, t: f64) bool {
                const current_finished = sequential.animations.items[sequential.current].update(t);

                if (current_finished == false) return false;

                if (sequential.current == sequential.animations.items.len - 1) return true;

                sequential.current += 1;
                sequential.animations.items[sequential.current].start();

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

            pub fn deinit(parallel: *Parallel) void {
                for (parallel.animations.items) |*a| {
                    a.deinit();
                }

                parallel.animations.deinit();
            }

            pub fn start(parallel: *Parallel) void {
                for (parallel.animations.items) |*a| {
                    a.start();
                }
            }

            pub fn addParallel(parallel: *Parallel) !*Parallel {
                const a = Parallel.init(parallel.alloc);
                const a_ptr = try parallel.animations.addOne();
                a_ptr.* = AnimationType{ .parallel = a };
                return &(a_ptr.*.parallel);
            }

            pub fn addSequential(parallel: *Parallel) !*Sequential {
                const a = Sequential.init(parallel.alloc);
                const a_ptr = try parallel.animations.addOne();
                a_ptr.* = AnimationType{ .sequential = a };
                return &(a_ptr.*.sequential);
            }

            pub fn addProperty(parallel: *Parallel, a: Property) !void {
                const a_ptr = try parallel.animations.addOne();
                a_ptr.* = AnimationType{ .property = a };
            }

            pub fn update(parallel: *Parallel, t: f64) bool {
                var finished = true;

                for (parallel.animations.items) |*a| {
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
    const allocator = testing.allocator;

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
    const allocator = testing.allocator;

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
    return @as(f64, @floatFromInt(time.nanoTimestamp())) / 1_000_000_000.0;
}
