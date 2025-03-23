const std = @import("std");

const zbench = @import("zbench");
const zeit = @import("zeit");

const config = @import("config.zig");

const zdt_023 = @import("zdt_023");
const zdt_045 = @import("zdt_045");
const zdt_latest = @import("zdt_current");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// -------- ISO ------------------------------------------------------------------------------------
// parse an ISO8601 formatted string to a datetime

fn benchParseISOv023(_: std.mem.Allocator) void {
    _ = zdt_023.parseISO8601(config.str) catch unreachable;
}

fn benchParseISOv045(_: std.mem.Allocator) void {
    _ = zdt_045.Datetime.fromISO8601(config.str) catch unreachable;
}

fn benchParseISOlatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromISO8601(config.str) catch unreachable;
}

fn benchParseISOstrpv023(_: std.mem.Allocator) void {
    _ = zdt_023.parseToDatetime(config.directive, config.str) catch unreachable;
}

fn benchParseISOstrpv045(_: std.mem.Allocator) void {
    _ = zdt_045.Datetime.fromString(config.str, config.directive) catch unreachable;
}

fn benchParseISOstrplatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromString(config.str, config.directive) catch unreachable;
}

fn benchParseISOzeitInst(_: std.mem.Allocator) void {
    // only make an instant
    _ = zeit.instant(.{ .source = .{ .iso8601 = config.str } }) catch unreachable;
}

fn benchParseISOzeit(_: std.mem.Allocator) void {
    // make an instant and convert to datetime
    const t = zeit.instant(.{ .source = .{ .iso8601 = config.str } }) catch unreachable;
    _ = t.time();
}

// -------- MEMORY --------------------------------------------------------------------------------
// make a datetime in a timezone

fn benchZonedZdt045(allocator: std.mem.Allocator) void {
    var mytz: zdt_045.Timezone = zdt_045.Timezone.fromTzdata("Europe/Berlin", allocator) catch unreachable;
    defer mytz.deinit();
    _ = zdt_045.Datetime.now(.{ .tz = &mytz }) catch unreachable;
}

fn benchZonedZdt(allocator: std.mem.Allocator) void {
    var mytz: zdt_latest.Timezone = zdt_latest.Timezone.fromTzdata("Europe/Berlin", allocator) catch unreachable;
    defer mytz.deinit();
    _ = zdt_latest.Datetime.now(.{ .tz = &mytz }) catch unreachable;
}

fn benchZonedZdtZA(_: std.mem.Allocator) void {
    var mytz: zdt_latest.Timezone = zdt_latest.Timezone.fromTzdataZeroAlloc("Europe/Berlin") catch unreachable;
    _ = zdt_latest.Datetime.now(.{ .tz = &mytz }) catch unreachable;
}

fn benchZonedZeit(allocator: std.mem.Allocator) void {
    const now = zeit.instant(.{}) catch unreachable;
    const zone = zeit.loadTimeZone(allocator, .@"Europe/Berlin", null) catch unreachable;
    const now_local = now.in(&zone);
    _ = now_local.time();
}

// -------- EASTER --------------------------------------------------------------------------------

fn benchEasterLatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.EasterDate(2025) catch unreachable;
}

fn benchEasterJulLatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.EasterDateJulian(2025) catch unreachable;
}

pub fn run() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer bench.deinit();

    try bench.add("iso zdt v0.2.3", benchParseISOv023, .{ .iterations = config.N });
    try bench.add("iso zdt v0.4.5", benchParseISOv045, .{ .iterations = config.N });
    try bench.add("iso zdt latest", benchParseISOlatest, .{ .iterations = config.N });
    try bench.add("iso zdt strp v0.2.3", benchParseISOstrpv023, .{ .iterations = config.N });
    try bench.add("iso zdt strp v0.4.5", benchParseISOstrpv045, .{ .iterations = config.N });
    try bench.add("iso zdt strp latest", benchParseISOstrplatest, .{ .iterations = config.N });

    try bench.add("\niso zeit 0.6 inst", benchParseISOzeitInst, .{ .iterations = config.N });
    try bench.add("iso zeit 0.6 full", benchParseISOzeit, .{ .iterations = config.N });

    try bench.add("\nEaster dt zdt latest", benchEasterLatest, .{ .iterations = config.N });
    try bench.add("Easter JL zdt latest", benchEasterJulLatest, .{ .iterations = config.N });

    try bench.add("\nZoned local, v0.4.5", benchZonedZdt045, .{ .iterations = 1000 });
    try bench.add("Zoned local, zdt lt", benchZonedZdt, .{ .iterations = 1000 });
    try bench.add("Zoned local, zdt lt", benchZonedZdt, .{ .iterations = 1000, .track_allocations = true });
    try bench.add("(Zero-Alloc) zdt lt", benchZonedZdtZA, .{ .iterations = 1000 });

    try bench.add("\nZoned local, zeit", benchZonedZeit, .{ .iterations = 1000 });
    try bench.add("Zoned local, zeit", benchZonedZeit, .{ .iterations = 1000, .track_allocations = true });

    try stdout.writeAll("\n");
    try bench.run(stdout);

    std.debug.print("\n", .{});
}
