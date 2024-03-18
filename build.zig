const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const epoll = b.dependency("foxwhale_epoll", .{ .target = target, .optimize = optimize });
    const pool = b.dependency("foxwhale_pool", .{ .target = target, .optimize = optimize });
    const subset_pool = b.dependency("foxwhale_subset_pool", .{ .target = target, .optimize = optimize });
    const iterable_pool = b.dependency("foxwhale_iterable_pool", .{ .target = target, .optimize = optimize });
    const wayland = b.dependency("foxwhale_wayland", .{ .target = target, .optimize = optimize });
    const backend = b.dependency("foxwhale_backend", .{ .target = target, .optimize = optimize });
    const animation = b.dependency("foxwhale_animation", .{ .target = target, .optimize = optimize });
    const ease = b.dependency("foxwhale_ease", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "foxwhale",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });

    exe.root_module.addImport("foxwhale-epoll", epoll.module("foxwhale-epoll"));
    exe.root_module.addImport("foxwhale-pool", pool.module("foxwhale-pool"));
    exe.root_module.addImport("foxwhale-subset-pool", subset_pool.module("foxwhale-subset-pool"));
    exe.root_module.addImport("foxwhale-iterable-pool", iterable_pool.module("foxwhale-iterable-pool"));
    exe.root_module.addImport("foxwhale-wayland", wayland.module("foxwhale-wayland"));
    exe.root_module.addImport("foxwhale-backend", backend.module("foxwhale-backend"));
    exe.root_module.addImport("foxwhale-animation", animation.module("foxwhale-animation"));
    exe.root_module.addImport("foxwhale-ease", ease.module("foxwhale-ease"));

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("xkbcommon");
    // exe.linkSystemLibrary("xkbcommon-x11");
    exe.linkSystemLibrary("libsystemd");
    exe.linkSystemLibrary("libudev");
    exe.linkSystemLibrary("libinput");
    exe.linkSystemLibrary("libdrm");
    exe.linkSystemLibrary("gbm");
    exe.linkSystemLibrary("egl");
    exe.linkSystemLibrary("xcb");
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("X11-xcb");

    b.installArtifact(exe);

    // FIXME: fix client generation of protocols
    // const foxwhalectl_exe = b.addExecutable("foxwhalectl", "src/foxwhalectl/main.zig");
    // foxwhalectl_exe.setTarget(target);
    // foxwhalectl_exe.setBuildMode(mode);
    // if (mode != .Debug) {
    //     foxwhalectl_exe.strip = true;
    // }
    // foxwhalectl_exe.single_threaded = true;
    // foxwhalectl_exe.install();
    // foxwhalectl_exe.addPackagePath("epoll", "src/epoll.zig");
    // foxwhalectl_exe.addPackagePath("wl", "src/wl/wire.zig");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Generate
    // ===========================
    const foxwhale_gen = b.dependency("foxwhale_gen", .{ .target = target, .optimize = optimize });
    const foxwhale_gen_exe = foxwhale_gen.artifact("foxwhale-gen");

    const output_path = "foxwhale-wayland/src/protocols.zig";
    const gen_cmd = b.addRunArtifact(foxwhale_gen_exe);
    gen_cmd.addArg("server");
    gen_cmd.addArg("--input-file");
    gen_cmd.addArg("/usr/share/wayland/wayland.xml");
    gen_cmd.addArg("--input-file");
    gen_cmd.addArg("/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml");
    gen_cmd.addArg("--input-file");
    gen_cmd.addArg("/usr/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml");
    gen_cmd.addArg("--input-file");
    gen_cmd.addArg("protocols/fw_control.xml");
    gen_cmd.addArg("--output-file");
    gen_cmd.addArg(output_path);

    const gen_step = b.step("generate", "Generate wayland protocols");

    const fmt_step = b.addFmt(.{ .paths = &.{output_path} });
    fmt_step.step.dependOn(&gen_cmd.step);

    gen_step.dependOn(&fmt_step.step);
}
