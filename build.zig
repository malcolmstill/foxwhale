const Builder = @import("std").build.Builder;
const std = @import("std");

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("foxwhale", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("xkbcommon");
    exe.linkSystemLibrary("libsystemd");
    exe.linkSystemLibrary("libudev");
    exe.linkSystemLibrary("libinput");
    exe.linkSystemLibrary("libdrm");
    exe.linkSystemLibrary("gbm");
    exe.linkSystemLibrary("egl");
    if (mode != .Debug) {
        exe.strip = true;
    }
    exe.single_threaded = true;
    exe.install();

    const foxwhalectl_exe = b.addExecutable("foxwhalectl", "src/foxwhalectl/main.zig");
    foxwhalectl_exe.setTarget(target);
    foxwhalectl_exe.setBuildMode(mode);
    if (mode != .Debug) {
        foxwhalectl_exe.strip = true;
    }
    foxwhalectl_exe.single_threaded = true;
    foxwhalectl_exe.install();
    foxwhalectl_exe.addPackagePath("epoll", "src/epoll.zig");
    foxwhalectl_exe.addPackagePath("wl", "src/wl/context.zig");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}