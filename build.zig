const std = @import("std");

// const example_files = [_][]const u8{
//     "ex_datetime", "ex_duration", "ex_helpers",
// };

const test_files = [_][]const u8{
    "test_datetime",
    "test_calendar",
    "test_timezone",
    //    "zdt",
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
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

    const lib = b.addStaticLibrary(.{
        .name = "zdt",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
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
        });
        const run_test = b.addRunArtifact(_test);
        test_step.dependOn(&run_test.step);
    }

    // --------------------------------------------------------------------------------
    // benchmarks (as binary 'benchmarks')
    // const bench_step = b.step("bench", "Run benchmarks");
    // const benchmarks = b.addExecutable(
    //     .{
    //         .name = "benchmarks",
    //         .root_source_file = .{ .path = "src/benchmarks.zig" },
    //         .target = target,
    //         .optimize = optimize,
    //     },
    // );
    // const zbench = b.dependency("zbench", .{ .target = target, .optimize = optimize });
    // benchmarks.addModule("zbench", zbench.module("zbench"));
    // benchmarks.linkLibrary(zbench.artifact("zbench"));
    // const build_benchmarks = b.addInstallArtifact(benchmarks, .{});
    // bench_step.dependOn(&build_benchmarks.step);

    // --------------------------------------------------------------------------------
    // examples (as binaries with a main() that prints stuff to stderr)
    // build via 'zig build examples'
    // build & run via 'zig build examples && ./zig-out/bin/[example-name]'
    // const zdt_mod = b.addModule("zdt", .{ .source_file = .{ .path = "src/zdt.zig" } });
    // const example_step = b.step("examples", "Build examples");
    // // Add new examples here
    // for (example_files) |example_name| {
    //     const example = b.addExecutable(.{
    //         .name = example_name,
    //         .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     example.addModule("zdt", zdt_mod);
    //     const install_example = b.addInstallArtifact(example, .{});
    //     example_step.dependOn(&example.step);
    //     example_step.dependOn(&install_example.step);
    // }
}
