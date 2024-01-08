const std = @import("std");
const builtin = @import("builtin");

const example_files = [_][]const u8{
    "ex_datetime",
    "ex_offsetTz",
    "ex_timezones",
};

const bench_files = [_][]const u8{
    "bench_calendar",
    "bench_isoparse",
};

const test_files = [_][]const u8{
    "zdt",
    "test_calendar",
    "test_datetime",
    "test_duration",
    "test_stringIO",
    "test_timezone",
};

const req_zig_version = "0.12.0-dev";

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
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // export the module itself
    const zdt_module = b.addModule("zdt", .{
        .root_source_file = .{ .path = "src/zdt.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "zdt",
        .root_source_file = .{ .path = "src/zdt.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // --------------------------------------------------------------------------------
    // tests (run once only, if the source has changed)
    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const test_step = b.step("tests", "Run library tests");
    for (test_files) |test_name| {
        const _test = b.addTest(.{
            .name = test_name,
            .root_source_file = .{ .path = b.fmt("src/{s}.zig", .{test_name}) },
            .target = target,
            .optimize = optimize,
            // .test_runner = "./test_runner.zig",
        });
        const run_test = b.addRunArtifact(_test);
        // run tests without caching, but no re-compilation if source unchanged:
        run_test.has_side_effects = true;
        test_step.dependOn(&run_test.step);
    }

    // --------------------------------------------------------------------------------
    // benchmarks (as binaries 'bench_*')
    // FIXME : benchmarks currently do not work since zbench is incompatible with zig 0.12.0-dev
    // const bench_step = b.step("benchmarks", "Build benchmark");
    // const zbench_module = b.dependency("zbench", .{ .target = target, .optimize = optimize }).module("zbench");
    // for (bench_files) |bench_name| {
    //     const _bench = b.addExecutable(.{
    //         .name = bench_name,
    //         .root_source_file = .{ .path = b.fmt("src/{s}.zig", .{bench_name}) },
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     _bench.root_module.addImport("zbench", zbench_module);
    //     const install_bench = b.addInstallArtifact(_bench, .{});
    //     bench_step.dependOn(&_bench.step);
    //     bench_step.dependOn(&install_bench.step);
    // }

    // --------------------------------------------------------------------------------
    // examples (as binaries with a main() that prints stuff to stderr)
    // build via 'zig build examples'
    // build & run via 'zig build examples && ./zig-out/bin/[example-name]'
    const example_step = b.step("examples", "Build examples");
    for (example_files) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        example.root_module.addImport("zdt", zdt_module);
        const install_example = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
    }
}
