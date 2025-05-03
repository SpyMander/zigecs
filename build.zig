const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // expose library
    _ = b.addModule("zigecs", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // test stuff

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // options

    const maxEntities = b.option(u32, "maxEntities", "maximum entity limit for the ecs (default=1024)") orelse 1024;

    const options = b.addOptions();
    options.addOption(u32, "maxEntities", maxEntities);

    lib_unit_tests.root_module.addOptions("zigecsOptions", options);

    b.installArtifact(lib_unit_tests);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    if (b.args) |args| {
        run_lib_unit_tests.addArgs(args);
    }

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
