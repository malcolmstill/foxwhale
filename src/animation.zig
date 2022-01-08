const std = @import("std");
const mem = std.mem;
const time = std.time;
const ArrayList = std.ArrayList;

const AnimationType = enum {
    property,
    sequential,
    // parallel,
};

const Animation = union(AnimationType) {
    property: PropertyAnimation,
    sequential: SequentialAnimation,
    // parallel: ParallelAnimation,

    fn start(self: *Animation) void {
        switch (self.*) {
            .property => |*p| p.start(),
            .sequential => |*s| s.start(),
        }
    }

    fn update(self: *Animation, t: f64) bool {
        return switch (self.*) {
            .property => |*p| p.update(t),
            .sequential => |*s| s.update(t),
        };
    }

    fn deinit(self: *Animation) void {
        switch (self.*) {
            .property => {},
            .sequential => |*s| s.deinit(),
            // .parallel => |p| p.deinit(),
        }
    }
};

const PropertyAnimation = struct {
    initial_value: f64,
    final_value: f64,
    start_time: f64 = 0.0,
    duration: f64,
    // easing: fn ()
    property: []const u8,
    target: anytype,

    fn start(self: *PropertyAnimation) void {
        self.start_time = now();
    }

    fn update(self: *PropertyAnimation, t: f64) bool {
        if (t < self.start_time) return false;

        // TODO: set final value
        if (self.duration <= 0.0 or t > self.start_time + self.duration) return true;

        const progress = (t - self.start_time) / self.duration;
        const new_value = self.initial_value + (self.final_value - self.initial_value) * progress;

        @field(self.target, self.property) = new_value;

        return false;
    }
};

const SequentialAnimation = struct {
    animations: ArrayList(Animation),
    current: usize = 0,

    fn init(allocator: *mem.Allocator) SequentialAnimation {
        return SequentialAnimation{
            .animations = ArrayList(Animation).init(allocator),
        };
    }

    fn deinit(self: *SequentialAnimation) void {
        for (self.animations.items) |*a| {
            a.deinit();
        }

        self.animations.deinit();
    }

    fn start(self: *SequentialAnimation) void {
        if (self.animations.items.len == 0) return;
        self.animations.items[0].start();
    }

    // Returns true if animation finished
    fn update(self: *SequentialAnimation, t: f64) bool {
        const current_finished = self.animations.items[self.current].update(t);

        if (current_finished == false) return false;

        if (self.current == self.animations.items.len - 1) return true;

        self.current += 1;
        self.animations.items[self.current].start();

        return false;
    }
};

// const ParallelAnimation = struct {
//     animations: ArrayList(Animation),

//     fn init(allocator: *mem.Allocator) ParallelAnimation {
//         return ParallelAnimation{
//             .animations = ArrayList(Animation).init(allocator),
//         };
//     }

//     fn deinit(self: *ParallelAnimation) void {
//         for (self.animations.items) |*a| {
//             switch (a) {
//                 .sequential => |s| s.deinit(),
//                 .parallel => |p| p.deinit(),
//                 .simple => {},
//             }
//         }

//         self.animations.deinit();
//     }
// };

const testing = std.testing;

test "Animations" {
    var allocator = testing.allocator;

    var seq = SequentialAnimation.init(allocator);
    defer seq.deinit();

    try seq.animations.append(Animation{
        .property = PropertyAnimation{
            .initial_value = 22.5,
            .final_value = 88.1,
            .duration = 1.0,
            .property = "x",
        },
    });

    try seq.animations.append(Animation{
        .property = PropertyAnimation{
            .initial_value = 122.5,
            .final_value = 58.1,
            .duration = 1.0,
            .property = "x",
        },
    });

    seq.start();
    while (!seq.update(now())) {
        time.sleep(16_000_000);
    }
}

// seconds
fn now() f64 {
    return @intToFloat(f64, time.nanoTimestamp()) / 1_000_000_000.0;
}
