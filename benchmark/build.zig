const std = @import("std");
const log = std.log.scoped(.benchmark_build);

const benchmarks = [_][]const u8{
    "main",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zdt_030 = b.dependency("zdt_030", .{});
    const zdt_045 = b.dependency("zdt_045", .{});

    const zdt_030_module = zdt_030.module("zdt");
    const zdt_045_module = zdt_045.module("zdt");

    for (benchmarks) |benchname| {
        const _bench = b.addExecutable(.{
            .name = benchname,
            .root_source_file = b.path(b.fmt("src/{s}.zig", .{benchname})),
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(_bench);
        _bench.root_module.addImport("zdt_030", zdt_030_module);
        _bench.root_module.addImport("zdt_045", zdt_045_module);
        _bench.linkLibC();

        const run_cmd = b.addRunArtifact(_bench);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step("run", "run benchmark");
        run_step.dependOn(&run_cmd.step);
    }
}
