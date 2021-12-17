const AnimationInterface = struct {
    startFn: fn (*AnimationInterface) void,
    updateFn: fn (*AnimationInterface) void,
    stopFn: fn (*AnimationInterface) void,

    pub fn start(self: *AnimationInterface) void {
        return self.startFn(self);
    }

    pub fn update(self: *AnimationInterface) void {
        return self.updateFn(self);
    }

    pub fn stop(self: *AnimationInterface) void {
        return self.stopFn(self);
    }
};

const Animation = struct {
    start_time: usize,
    duration: usize,
};

const ParallelAnimation = struct {
    animations: []AnimationInterface,
};

test "Animations" {
    //
}
