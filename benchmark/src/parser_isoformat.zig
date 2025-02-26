const std = @import("std");
const print = std.debug.print;
const Timer = std.time.Timer;

// const zdt_023 = @import("zdt_023");
const zdt_045 = @import("zdt_045");
const zdt_current = @import("zdt_current");

pub const N: u32 = 100_000;
pub const str: []const u8 = "2022-08-03T13:44:01.994Z";
pub const directive: []const u8 = "%Y-%m-%dT%H:%M:%S.%f%z";

// pub fn parse_iso_023() !void {
//     var i: usize = 0;
//     while (i < N) : (i += 1) {
//         const t = try zdt_023.parseISO8601(str);
//         std.mem.doNotOptimizeAway(t);
//     }
// }

// pub fn parse_iso_strp_023() !void {
//     var i: usize = 0;
//     while (i < N) : (i += 1) {
//         const t = try zdt_023.parseToDatetime(directive, str);
//         std.mem.doNotOptimizeAway(t);
//     }
// }

pub fn parse_iso_045() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_045.Datetime.fromISO8601(str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_045() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_045.Datetime.fromString(str, directive);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_latest() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_current.Datetime.fromISO8601(str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_latest() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_current.Datetime.fromString(str, directive);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn run_isoparse_bench_simple() !void {
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
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / N });
    }

    // ---

    print("\n-- zdt 045: parse ISO format\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_045();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / N });
    }

    // ---

    print("\n-- zdt latest: parse ISO format with strptime\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_strp_latest();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / N });
    }

    // ---

    print("\n-- zdt 045: parse ISO format with strptime\n", .{});
    i = 0;
    while (i < n_runs) : (i += 1) {
        t.reset();
        t0 = t.read();
        _ = try parse_iso_strp_045();
        t1 = t.read();
        print("run {d} of {d}: {d} ns per run\n", .{ i + 1, n_runs, (t1 - t0) / N });
    }
}
