const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.zdt_build);

const zdt_version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 22 };

const example_files = [_][]const u8{
    "ex_demo",
    "ex_datetime",
    "ex_duration",
    "ex_offsetTz",
    "ex_strings",
    "ex_timezones",
};

const test_files = [_][]const u8{
    "test_calendar",
    "test_datetime",
    "test_duration",
    "test_stringIO",
    "test_timezone",
};

// const bench_files = [_][]const u8{
//     "bench_calendar",
//     "bench_isoparse",
// };

const tz_submodule_dir = "tz";

const tzdb_prefix_default = "lib/tzdata/zoneinfo";

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

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tzdb_prefix = b.option(
        []const u8,
        "prefix-tzdb",
        "Absolute path to IANA time zone database, containing TZif files",
    ) orelse tzdb_prefix_default;

    const zdt_module = b.addModule("zdt", .{
        .root_source_file = .{ .path = "zdt.zig" },
    });

    const zdt = b.addStaticLibrary(.{
        .name = "zdt",
        .root_source_file = .{ .path = "zdt.zig" },
        .target = target,
        .optimize = optimize,
        .version = zdt_version,
    });

    zdt.linkLibC();
    b.installArtifact(zdt);
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // path prefix to tz data should always be updated on install
    const install = b.getInstallStep();
    const tzprefix_step = b.step("tz-update-prefix", "generate timezone database prefix (path)");

    var gen_tzdb_prefix = b.addExecutable(.{
        .name = "gen_tzdb_prefix",
        .root_source_file = .{ .path = "util/gen_tzdb_prefix.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_gen_prefix = b.addRunArtifact(gen_tzdb_prefix);
    run_gen_prefix.step.dependOn(&gen_tzdb_prefix.step);
    run_gen_prefix.addArg(tzdb_prefix_default);
    run_gen_prefix.addArg(tzdb_prefix);

    const out_file_p = run_gen_prefix.addOutputFileArg("tzdb_prefix.zig");
    // since this step is run on install, we can use the prefix step as an anonymous import
    zdt_module.addAnonymousImport("tzdb_prefix", .{ .root_source_file = out_file_p });

    // the prefix step should always run since the tzdb prefix is specific to the
    // system that the library is used on:
    zdt.step.dependOn(tzprefix_step);
    install.dependOn(tzprefix_step);
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // update tz database and version info
    const tzdata_version_update_step = b.step("tz-update-version", "update timezone database version info");
    {
        var gen_tzdb_version = b.addExecutable(.{
            .name = "gen_tzdb_version",
            .root_source_file = .{ .path = "util/gen_tzdb_version.zig" },
            .target = target,
            .optimize = optimize,
        });

        const run_gen_version = b.addRunArtifact(gen_tzdb_version);
        run_gen_version.step.dependOn(&gen_tzdb_version.step);
        run_gen_version.addPathDir("lib");
        const out_file_v = run_gen_version.addOutputFileArg("tzdb_version.zig");
        const write_files_v = b.addWriteFiles();
        write_files_v.addCopyFileToSource(out_file_v, "./lib/tzdb_version.zig");
        tzdata_version_update_step.dependOn(&write_files_v.step);
    }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // update tz database and version info
    const tzdata_update_step = b.step("tz-update-db", "update timezone database");
    {
        var gen_tzdb = b.addExecutable(.{
            .name = "gen_tzdb",
            .root_source_file = .{ .path = "util/gen_tzdb.zig" },
            .target = target,
            .optimize = optimize,
        });

        const run_tzdata_update = b.addRunArtifact(gen_tzdb);
        run_tzdata_update.step.dependOn(&gen_tzdb.step);
        // where to run makefile of tzdata:
        run_tzdata_update.addArg(tz_submodule_dir);
        // target directory of the compilation:
        run_tzdata_update.addArg(tzdb_prefix);

        tzdata_update_step.dependOn(&run_tzdata_update.step);
        //        tzdata_update_step.dependOn(tzdata_version_update_step);
    }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // tests
    const test_step = b.step("tests", "Run library tests");
    {
        // unit tests in lib/*.zig files
        const root_test = b.addTest(.{
            .name = "zdt_root",
            .root_source_file = .{ .path = "zdt.zig" },
            .target = target,
            .optimize = optimize,
            // .test_runner = "./test_runner.zig",
        });
        root_test.linkLibC(); // stringIO has libc dependency
        const run_test_root = b.addRunArtifact(root_test);
        // run_test_root.has_side_effects = true;
        root_test.root_module.addImport("zdt", zdt_module);
        test_step.dependOn(&run_test_root.step);

        for (test_files) |test_name| {
            const _test = b.addTest(.{
                .name = test_name,
                .root_source_file = .{ .path = b.fmt("tests/{s}.zig", .{test_name}) },
                .target = target,
                .optimize = optimize,
                // .test_runner = "./test_runner.zig",
            });
            _test.linkLibC(); // stringIO has libc dependency
            const run_test = b.addRunArtifact(_test);
            // run_test.has_side_effects = true;
            _test.root_module.addImport("zdt", zdt_module);
            test_step.dependOn(&run_test.step);
        }
    }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // examples
    // - as binaries with a main() that prints stuff to stderr
    // build via 'zig build examples'
    // build & run via 'zig build examples && ./zig-out/bin/[example-name]'
    const example_step = b.step("examples", "Build examples");
    {
        for (example_files) |example_name| {
            const example = b.addExecutable(.{
                .name = example_name,
                .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
                .target = target,
                .optimize = optimize,
            });
            example.linkLibC();
            example.root_module.addImport("zdt", zdt_module);
            const install_example = b.addInstallArtifact(example, .{});
            example_step.dependOn(&example.step);
            example_step.dependOn(&install_example.step);
        }
    }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // clean step: remove ./zig-out and ./zig-cache
    const clean_step = b.step("clean", "Clean up");
    {
        clean_step.dependOn(&b.addRemoveDirTree(b.install_path).step);
        if (builtin.os.tag != .windows) {
            clean_step.dependOn(&b.addRemoveDirTree(b.pathFromRoot("zig-cache")).step);
        }
    }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // generate docs
    // const docs_step = b.step("docs", "auto-generate documentation");
    // {
    //     //    NOTE : atm, this does not work due to anonymous import
    //     const install_docs = b.addInstallDirectory(.{
    //         .source_dir = zdt.getEmittedDocs(),
    //         .install_dir = std.Build.InstallDir{ .custom = "../docs" },
    //         .install_subdir = "autogen",
    //     });
    //     docs_step.dependOn(&install_docs.step);
    // }
    // --------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------
    // benchmarks (as binaries 'bench_*')
    // NOTE : benchmarks currently do not work since zbench is incompatible with zig 0.12.0-dev
    // const bench_step = b.step("benchmarks", "Build benchmark");
    // {
    //     const zbench_module = b.dependency("zbench", .{ .target = target, .optimize = optimize }).module("zbench");
    //     for (bench_files) |bench_name| {
    //         const _bench = b.addExecutable(.{
    //             .name = bench_name,
    //             .root_source_file = .{ .path = b.fmt("benchmarks/{s}.zig", .{bench_name}) },
    //             .target = target,
    //             .optimize = optimize,
    //         });
    //         _bench.root_module.addImport("zbench", zbench_module);
    //         _bench.root_module.addImport("zdt", zdt_module);
    //         const install_bench = b.addInstallArtifact(_bench, .{});
    //         bench_step.dependOn(&_bench.step);
    //         bench_step.dependOn(&install_bench.step);
    //     }
    // }
    // --------------------------------------------------------------------------------
}
