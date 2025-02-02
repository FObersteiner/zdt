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

pub fn parse_iso_current() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_current.Datetime.fromISO8601(str);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn parse_iso_strp_current() !void {
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const t = zdt_current.Datetime.fromString(str, directive);
        std.mem.doNotOptimizeAway(t);
    }
}

pub fn run_isoparse_bench_simple() !void {
    var t = try Timer.start();
    var t0 = t.read();

    print("\n-- zdt current: parse ISO format\n", .{});
    _ = try parse_iso_current();
    var t1 = t.read();
    print("zdt_current: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_current();
    t1 = t.read();
    print("zdt_023: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_current();
    t1 = t.read();
    print("zdt_023: {d} ns per run\n", .{(t1 - t0) / N});

    // ---

    print("\n-- zdt 045: parse ISO format\n", .{});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_045();
    t1 = t.read();
    print("zdt_045: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_045();
    t1 = t.read();
    print("zdt_045: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_045();
    t1 = t.read();
    print("zdt_045: {d} ns per run\n", .{(t1 - t0) / N});

    // ---

    print("\n-- zdt 045: parse ISO format with strptime\n", .{});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_045();
    t1 = t.read();
    print("zdt_045 strp: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_045();
    t1 = t.read();
    print("zdt_045 strp: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_045();
    t1 = t.read();
    print("zdt_045 strp: {d} ns per run\n", .{(t1 - t0) / N});

    // ---

    print("\n-- zdt current: parse ISO format with strptime\n", .{});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_current();
    t1 = t.read();
    print("zdt_current strp: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_current();
    t1 = t.read();
    print("zdt_current strp: {d} ns per run\n", .{(t1 - t0) / N});
    t.reset();
    t0 = t.read();
    _ = try parse_iso_strp_current();
    t1 = t.read();
    print("zdt_023 strp: {d} ns per run\n", .{(t1 - t0) / N});
}
