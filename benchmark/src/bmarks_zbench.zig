const std = @import("std");
const config = @import("config.zig");

const zeit = @import("zeit");

const zbench = @import("zbench");
const zdt_latest = @import("zdt_current");

var gpa = std.heap.DebugAllocator(.{}){};

// -------- ISO ------------------------------------------------------------------------------------
// parse an ISO8601 formatted string to a datetime

fn benchParseISOlatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromISO8601(config.str) catch unreachable;
}

fn benchParseISOstrplatest(_: std.mem.Allocator) void {
    _ = zdt_latest.Datetime.fromString(config.str, config.directive) catch unreachable;
}

fn benchParseISOzeitInst(_: std.mem.Allocator) void {
    // only make an instant
    _ = zeit.instant(.{ .source = .{ .iso8601 = config.str } }) catch unreachable;
}
//
fn benchParseISOzeit(_: std.mem.Allocator) void {
    // make an instant and convert to datetime
    const t = zeit.instant(.{ .source = .{ .iso8601 = config.str } }) catch unreachable;
    _ = t.time();
}

// -------- MEMORY --------------------------------------------------------------------------------
// make a datetime in a timezone

fn benchZonedZdt(allocator: std.mem.Allocator) void {
    var mytz: zdt_latest.Timezone = zdt_latest.Timezone.fromTzdata("Europe/Berlin", allocator) catch unreachable;
    defer mytz.deinit();
    _ = zdt_latest.Datetime.now(.{ .tz = &mytz }) catch unreachable;
}

fn benchZonedZdtZA(_: std.mem.Allocator) void {
    var mytz: zdt_latest.Timezone = zdt_latest.Timezone.fromTzdata("Europe/Berlin", null) catch unreachable;
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
    var stdout = std.fs.File.stdout().writerStreaming(&.{});

    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer bench.deinit();

    try bench.add("iso zdt latest", benchParseISOlatest, .{ .iterations = config.N });
    try bench.add("iso zdt strp latest", benchParseISOstrplatest, .{ .iterations = config.N });

    try bench.add("\niso zeit 0.6 inst", benchParseISOzeitInst, .{ .iterations = config.N });
    try bench.add("iso zeit 0.6 full", benchParseISOzeit, .{ .iterations = config.N });

    try bench.add("\nEaster dt zdt latest", benchEasterLatest, .{ .iterations = config.N });
    try bench.add("Easter JL zdt latest", benchEasterJulLatest, .{ .iterations = config.N });

    try bench.add("Zoned local, zdt lt", benchZonedZdt, .{ .iterations = 1000 });
    try bench.add("Zoned local, zdt lt", benchZonedZdt, .{ .iterations = 1000, .track_allocations = true });
    try bench.add("(Zero-Alloc) zdt lt", benchZonedZdtZA, .{ .iterations = 1000 });

    try bench.add("\nZoned local, zeit", benchZonedZeit, .{ .iterations = 1000 });
    try bench.add("Zoned local, zeit", benchZonedZeit, .{ .iterations = 1000, .track_allocations = true });

    try bench.run(&stdout.interface);

    std.debug.print("\n", .{});
}
