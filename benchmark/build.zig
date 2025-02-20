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
    const zeit = b.dependency("zeit", .{});
    const zdt_023 = b.dependency("zdt_023", .{});
    const zdt_045 = b.dependency("zdt_045", .{});
    const zdt_current = b.dependency("zdt_current", .{});
    // TODO : labeled switch parser will require zig 0.14

    const zbench_module = zbench.module("zbench");
    const zeit_module = zeit.module("zeit");
    const zdt_023_module = zdt_023.module("zdt");
    const zdt_045_module = zdt_045.module("zdt");
    const zdt_current_module = zdt_current.module("zdt");

    for (benchmarks) |benchname| {
        const _bench = b.addExecutable(.{
            .name = benchname,
            .root_source_file = b.path(b.fmt("src/{s}.zig", .{benchname})),
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(_bench);
        _bench.root_module.addImport("zbench", zbench_module);
        _bench.root_module.addImport("zeit", zeit_module);
        _bench.root_module.addImport("zdt_023", zdt_023_module);
        _bench.root_module.addImport("zdt_045", zdt_045_module);
        _bench.root_module.addImport("zdt_current", zdt_current_module);
        _bench.linkLibC();

        const run_cmd = b.addRunArtifact(_bench);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step("run", "run benchmark");
        run_step.dependOn(&run_cmd.step);
    }
}
