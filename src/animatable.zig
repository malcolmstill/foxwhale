const std = @import("std");
const mem = std.mem;
const animation = @import("animation.zig");
const ArrayList = std.ArrayList;
const Animation = @import("animation.zig").Animation;
const Window = @import("window.zig").Window;

const AnimatableTypeTag = enum {
    window,
};

pub const AnimatableType = union(AnimatableTypeTag) {
    window: *Window,
};

pub const Animatable = Animation(AnimatableType);

pub const AnimationList = struct {
    alloc: *mem.Allocator,
    animations: ArrayList(Animatable),

    pub fn init(alloc: *mem.Allocator) AnimationList {
        return AnimationList{
            .alloc = alloc,
            .animations = ArrayList(Animatable).init(alloc),
        };
    }

    // pub fn add(self: *AnimationList, anim: Animatable) !void {
    //     try self.animations.append(anim);
    // }

    pub fn addParallel(self: *AnimationList) !*Animatable.Parallel {
        var a = Animatable.Parallel.init(self.alloc);
        const a_ptr = try self.animations.addOne();
        a_ptr.* = Animatable{ .parallel = a };
        return &(a_ptr.*.parallel);
    }

    pub fn addSequential(self: *AnimationList) !*Animatable.Sequential {
        var a = Animatable.Sequential.init(self.alloc);
        const a_ptr = try self.animations.addOne();
        a_ptr.* = Animatable{ .sequential = a };
        return &(a_ptr.*.sequential);
    }

    pub fn addProperty(self: *AnimationList, a: Animatable.Property) !void {
        const a_ptr = try self.animations.addOne();
        a_ptr.* = Animatable{ .property = a };
        return a_ptr;
    }

    pub fn update(self: *AnimationList) !void {
        var new_list = ArrayList(Animatable).init(self.alloc);
        const now = animation.now();
        std.debug.print("now = {}\n", .{now});

        for (self.animations.items) |*a| {
            const is_finished = a.update(now);

            if (is_finished) {
                a.deinit();
                continue;
            }

            try new_list.append(a.*);
        }

        self.animations.deinit();
        self.animations = new_list;
    }

    pub fn deinit(self: *AnimationList) void {
        for (self.animations.items) |*a| {
            a.deinit();
        }
        self.animations.deinit();
    }
};
