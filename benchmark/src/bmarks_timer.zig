const std = @import("std");
const print = std.debug.print;
const Timer = std.time.Timer;

const config = @import("config.zig");

const zdt_023 = @import("zdt_023");
const zdt_045 = @import("zdt_045");
const zdt_current = @import("zdt_current");

pub fn parse_iso_023() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = try zdt_023.parseISO8601(config.str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_023() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = try zdt_023.parseToDatetime(config.directive, config.str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_045() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = zdt_045.Datetime.fromISO8601(config.str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_045() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = zdt_045.Datetime.fromString(config.str, config.directive);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_latest() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = zdt_current.Datetime.fromISO8601(config.str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_latest() !void {
    var i: usize = 0;
    while (i < config.N) : (i += 1) {
        const t = zdt_current.Datetime.fromString(config.str, config.directive);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn run() !void {
    const n_runs: usize = 3;
    var i: usize = 0;
    var t0: u64 = 0;
    var t1: u64 = 0;
    var t = try Timer.start();

    // ---

    print("\n-- zdt latest: parse ISO format\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_latest();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    // ---

    print("\n-- zdt 045: parse ISO format\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_045();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    // ---

    print("\n-- zdt 023: parse ISO format\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_023();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    // ---

    print("\n-- zdt latest: parse ISO format with strptime\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_strp_latest();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    // ---

    print("\n-- zdt 045: parse ISO format with strptime\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_strp_045();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    // ---

    print("\n-- zdt 023: parse ISO format with strptime\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_strp_023();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / config.N });
    }

    print("\n", .{});
}
