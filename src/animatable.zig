const std = @import("std");
const mem = std.mem;
const ArrayList = std.ArrayList;

const Animation = @import("foxwhale-animation").Animation;
const now = @import("foxwhale-animation").now;

const Window = @import("resource/window.zig").Window;

const AnimatableTypeTag = enum {
    window,
};

pub const AnimatableType = union(AnimatableTypeTag) {
    window: *Window,
};

pub const Animatable = Animation(AnimatableType);

pub const AnimationList = struct {
    alloc: mem.Allocator,
    animations: ArrayList(Animatable),

    pub fn init(alloc: mem.Allocator) AnimationList {
        return AnimationList{
            .alloc = alloc,
            .animations = ArrayList(Animatable).init(alloc),
        };
    }

    // pub fn add(self: *AnimationList, anim: Animatable) !void {
    //     try self.animations.append(anim);
    // }

    pub fn addParallel(animation_list: *AnimationList) !*Animatable.Parallel {
        const a = Animatable.Parallel.init(animation_list.alloc);
        const a_ptr = try animation_list.animations.addOne();
        a_ptr.* = Animatable{ .parallel = a };
        return &(a_ptr.*.parallel);
    }

    pub fn addSequential(animation_list: *AnimationList) !*Animatable.Sequential {
        const a = Animatable.Sequential.init(animation_list.alloc);
        const a_ptr = try animation_list.animations.addOne();
        a_ptr.* = Animatable{ .sequential = a };
        return &(a_ptr.*.sequential);
    }

    pub fn addProperty(animation_list: *AnimationList, a: Animatable.Property) !void {
        const a_ptr = try animation_list.animations.addOne();
        a_ptr.* = Animatable{ .property = a };
        return a_ptr;
    }

    pub fn update(animation_list: *AnimationList) !void {
        var new_list = ArrayList(Animatable).init(animation_list.alloc);
        const time = now();

        for (animation_list.animations.items) |*a| {
            const is_finished = a.update(time);

            if (is_finished) {
                a.deinit();
                continue;
            }

            try new_list.append(a.*);
        }

        animation_list.animations.deinit();
        animation_list.animations = new_list;
    }

    pub fn deinit(animation_list: *AnimationList) void {
        for (animation_list.animations.items) |*a| {
            a.deinit();
        }
        animation_list.animations.deinit();
    }
};
