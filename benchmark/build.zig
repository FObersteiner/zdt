const std = @import("std");
const log = std.log.scoped(.benchmark_build);
const builtin = @import("builtin");

const benchmarks = [_][]const u8{
    "main",
};

const req_zig_version = "0.13.0";
comptime {
    const req_zig = std.SemanticVersion.parse(req_zig_version) catch unreachable;
    if (builtin.zig_version.order(req_zig) == .lt) {
        @compileError(std.fmt.comptimePrint(
            "Your Zig version v{} does not meet the minimum build requirement of v{}",
            .{ builtin.zig_version, req_zig },
        ));
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zbench = b.dependency("zbench", .{});
    const zdt_030 = b.dependency("zdt_030", .{});
    const zdt_045 = b.dependency("zdt_045", .{});
    // TODO : labeled switch parser will require zig 0.14

    const zbench_module = zbench.module("zbench");
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
        _bench.root_module.addImport("zbench", zbench_module);
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
