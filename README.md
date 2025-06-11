
# ZIGECS
an archetypal ecs for zig, smol and simple.

## INSTALL
... in an already existing project:

get the tarball-link through the releases.
run: `zig zig fetch --save "https://github.com/SpyMander/zigecs/archive/refs/tags/[VERIOSN_TAG].tar.gz"`

zig build config example:
``` zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "usinglibs.d",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ecs library
    const ecs_dep = b.dependency("ecs", .{
        .target = target,
        .optimize = optimize,
    });

    const ecs = ecs_dep.module("zigecs");
    exe.root_module.addImport("zigecs", ecs);

    // options

    const maxEntities = b.option(u32, "maxEntities", "maximum entity limit for the ecs (default=1024)") orelse 1024;

    const options = b.addOptions();
    options.addOption(u32, "maxEntities", maxEntities);

    ecs.addOptions("zigecsOptions", options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

the important bit in the config is the max entity limit.
be sure to add the options to the zigecs module

## EXAMPLE
``` zig
const std = @import("std");
const archetypeManager = @import("zigecs").ArchetypeManager;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }

    var x = arhcetypeManager.init(gpa.allocator());
    defer x.deinit();

    const randoType = &[_]type{ u32, f32 };
    x.addArchetype(randoType);

    x.insert(
        0,
        randoType,
        .{
            @as(u32, 5),
            @as(f32, 12.4),
        },
    );

    var iter = x.getComponentIterator(&[_]type{u32});
    while (iter.next()) {
        const value = iter.get(u32);

        try stdout.print("value: {}\n", .{value.*});
    }

    try stdout.print("hi\n", .{});

    try bw.flush(); // don't forget to flush!
}
```


## Features to be added in the future:
1. removing archetypeManager at runtime
2. auto inserting creating an archetype automatically
_and other stuff?_
