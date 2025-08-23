const std = @import("std");
const log = std.log.scoped(.benchmark_build);
const builtin = @import("builtin");

const benchmarks = [_][]const u8{
    "main",
};

const min_zig = std.SemanticVersion.parse("0.15.0-dev") catch unreachable;
comptime {
    if (builtin.zig_version.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint(
            "Your Zig version v{f} does not meet the minimum build requirement of v{f}",
            .{ builtin.zig_version, min_zig },
        ));
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zeit = b.dependency("zeit", .{});
    const zbench = b.dependency("zbench", .{});
    const zdt_latest = b.dependency("zdt_latest", .{});

    const zeit_module = zeit.module("zeit");
    const zbench_module = zbench.module("zbench");
    const zdt_latest_module = zdt_latest.module("zdt");

    for (benchmarks) |benchname| {
        const _bench = b.addExecutable(.{
            .name = benchname,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("src/{s}.zig", .{benchname})),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(_bench);
        _bench.root_module.addImport("zeit", zeit_module);
        _bench.root_module.addImport("zbench", zbench_module);
        _bench.root_module.addImport("zdt_current", zdt_latest_module);
        _bench.linkLibC();

        const run_cmd = b.addRunArtifact(_bench);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step("run", "run benchmark");
        run_step.dependOn(&run_cmd.step);
    }
}
