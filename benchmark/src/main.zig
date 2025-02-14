const std = @import("std");

const zbench = @import("zbench");
const zeit = @import("zeit");

// const zdt_023 = @import("zdt_023");
const zdt_045 = @import("zdt_045");
const zdt_latest = @import("zdt_current");

const pbs = @import("parser_isoformat.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// -------- ISO ------------------------------------------------------------------------------------
// parse an ISO8601 formatted string to a datetime

fn benchParseISOv045(_: std.mem.Allocator) void {
    _ = zdt_045.Datetime.fromISO8601(pbs.str) catch unreachable;
}

fn benchParseISOlatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromISO8601(pbs.str) catch unreachable;
}

fn benchParseISOstrplatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromString(pbs.str, pbs.directive) catch unreachable;
}

fn benchParseISOzeit(_: std.mem.Allocator) void {
    const t = zeit.instant(.{ .source = .{ .iso8601 = pbs.str } }) catch unreachable;
    _ = t.time();
}

// -------- MEMORY --------------------------------------------------------------------------------
// make a datetime in a timezone

fn benchZonedZdt(allocator: std.mem.Allocator) void {
    var mytz: zdt_latest.Timezone = zdt_latest.Timezone.fromTzdata("Europe/Berlin", allocator) catch unreachable;
    defer mytz.deinit();
    _ = zdt_latest.Datetime.now(.{ .tz = &mytz }) catch unreachable;
}

fn benchZonedZeit(allocator: std.mem.Allocator) void {
    const now = zeit.instant(.{}) catch unreachable;
    const zone = zeit.loadTimeZone(allocator, .@"Europe/Berlin", null) catch unreachable;
    const now_local = now.in(&zone);
    _ = now_local.time();
}

// -------- EASTER --------------------------------------------------------------------------------

fn benchEasterv046(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.EasterDate(2025) catch unreachable;
}

fn benchEasterJulv046(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.EasterDateJulian(2025) catch unreachable;
}

pub fn main() !void {
    _ = try pbs.run_isoparse_bench_simple();

    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer bench.deinit();

    // try bench.add("parse iso zdt v0.2.3", benchParseISOv023, .{ .iterations = pbs.N });
    try bench.add("parse iso zdt v0.4.5", benchParseISOv045, .{ .iterations = pbs.N });
    try bench.add("parse iso zdt latest", benchParseISOlatest, .{ .iterations = pbs.N });
    try bench.add("parse iso zdt strptm", benchParseISOstrplatest, .{ .iterations = pbs.N });

    try bench.add("parse iso zeit 0.5.0", benchParseISOzeit, .{ .iterations = pbs.N });

    try bench.add("\nEaster dt zdt latest", benchEasterv046, .{ .iterations = pbs.N });
    try bench.add("Easter JL zdt latest", benchEasterJulv046, .{ .iterations = pbs.N });

    try bench.add("\nZoned local, zdt", benchZonedZdt, .{ .iterations = 1000 });
    try bench.add("Zoned local, zdt", benchZonedZdt, .{ .iterations = 1000, .track_allocations = true });
    try bench.add("Zoned local, zeit", benchZonedZeit, .{ .iterations = 1000 });
    try bench.add("Zoned local, zeit", benchZonedZeit, .{ .iterations = 1000, .track_allocations = true });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
