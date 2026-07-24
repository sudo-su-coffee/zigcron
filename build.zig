const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Module export for Zig package ecosystem
    const zigcron_module = b.addModule("zigcron", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 2. Main Executable Daemon
    const exe = b.addExecutable(.{
        .name = "zigcron",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC(); // Required for C allocator & system operations
    exe.root_module.addImport("zigcron", zigcron_module);
    b.installArtifact(exe);

    // 3. C-ABI Dynamic Shared Library (.so / .dylib / .dll)
    const lib = b.addSharedLibrary(.{
        .name = "zigcron",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    b.installArtifact(lib);

    // 4. Unit Test Suite
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}