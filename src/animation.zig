const std = @import("std");
const mem = std.mem;
const math = std.math;
const time = std.time;
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

        fn start(self: *Self) void {
            switch (self.*) {
                .property => |*p| p.start(),
                .sequential => |*s| s.start(),
                .parallel => |*p| p.start(),
            }
        }

        fn update(self: *Self, t: f64) bool {
            return switch (self.*) {
                .property => |*p| p.update(t),
                .sequential => |*s| s.update(t),
                .parallel => |*p| p.update(t),
            };
        }

        fn deinit(self: *Self) void {
            switch (self.*) {
                .property => {},
                .sequential => |*s| s.deinit(),
                .parallel => |*p| p.deinit(),
            }
        }

        const Property = struct {
            initial_value: f64,
            final_value: f64,
            start_time: f64 = 0.0,
            duration: f64,
            easing: fn (f64) f64,
            property: []const u8,
            target: Targets,

            fn start(self: *Property) void {
                self.start_time = now();
            }

            fn update(self: *Property, t: f64) bool {
                if (t < self.start_time) return false;

                if (self.duration <= 0.0 or t > self.start_time + self.duration) {
                    self.set(self.final_value);
                    return true;
                }

                const progress = self.easing((t - self.start_time) / self.duration);
                const new_value = self.initial_value + (self.final_value - self.initial_value) * progress;

                self.set(new_value);

                return false;
            }

            fn set(self: *Property, value: f64) void {
                const info = @typeInfo(@TypeOf(@field(self.target, @tagName(self.target))));
                inline for (@typeInfo(info.Pointer.child).Struct.fields) |field| {
                    if (mem.eql(u8, self.property, field.name)) {
                        // std.debug.print("{s} = {}\n", .{ field.name, value });
                        @field(@field(self.target, @tagName(self.target)), field.name) = value;
                    }
                }
            }
        };

        const Sequential = struct {
            animations: ArrayList(Self),
            current: usize = 0,

            fn init(allocator: *mem.Allocator) Sequential {
                return Sequential{
                    .animations = ArrayList(Self).init(allocator),
                };
            }

            fn deinit(self: *Sequential) void {
                for (self.animations.items) |*a| {
                    a.deinit();
                }

                self.animations.deinit();
            }

            fn start(self: *Sequential) void {
                if (self.animations.items.len == 0) return;
                self.animations.items[0].start();
            }

            fn update(self: *Sequential, t: f64) bool {
                const current_finished = self.animations.items[self.current].update(t);

                if (current_finished == false) return false;

                if (self.current == self.animations.items.len - 1) return true;

                self.current += 1;
                self.animations.items[self.current].start();

                return false;
            }
        };

        const Parallel = struct {
            animations: ArrayList(Self),

            fn init(allocator: *mem.Allocator) Parallel {
                return Parallel{
                    .animations = ArrayList(Self).init(allocator),
                };
            }

            fn deinit(self: *Parallel) void {
                for (self.animations.items) |*a| {
                    a.deinit();
                }

                self.animations.deinit();
            }

            fn start(self: *Parallel) void {
                for (self.animations.items) |*a| {
                    a.start();
                }
            }

            fn update(self: *Parallel, t: f64) bool {
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
        x: f64,
        y: f64,
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
        .easing = easeInOutSine,
        .duration = 0.125,
        .property = "x",
        .target = x,
    } });

    try seq.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 50.0,
        .final_value = 0.0,
        .easing = easeInOutSine,
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
        x: f64,
        y: f64,
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
        .easing = easeInOutSine,
        .duration = 0.125,
        .property = "x",
        .target = x,
    } });

    try par.animations.append(Anim{ .property = Anim.Property{
        .initial_value = 50.0,
        .final_value = 0.0,
        .easing = easeInOutSine,
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
fn now() f64 {
    return @intToFloat(f64, time.nanoTimestamp()) / 1_000_000_000.0;
}

fn easeInOutSine(x: f64) f64 {
    return -(math.cos(math.pi * x) - 1.0) / 2.0;
}
