const std = @import("std");

const zbench = @import("zbench");

const zdt_023 = @import("zdt_023");
const zdt_045 = @import("zdt_045");
const zdt_046 = @import("zdt_046");

const pbs = @import("parser_isoformat.zig");

fn benchParseISOv023(_: std.mem.Allocator) void {
    _ = zdt_023.parseISO8601(pbs.str) catch unreachable;
}

fn benchParseISOv045(_: std.mem.Allocator) void {
    _ = zdt_045.Datetime.fromISO8601(pbs.str) catch unreachable;
}

fn benchEasterv046(_: std.mem.Allocator) void {
    _ = zdt_046.Datetime.EasterDate(2025) catch unreachable;
}

fn benchEasterJulv046(_: std.mem.Allocator) void {
    _ = zdt_046.Datetime.EasterDateJulian(2025) catch unreachable;
}

pub fn main() !void {
    _ = try pbs.run_isoparse_bench_simple();

    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("parse iso zdt v0.2.3", benchParseISOv023, .{ .iterations = 50_000 });
    try bench.add("parse iso zdt v0.4.5", benchParseISOv045, .{ .iterations = 50_000 });
    try bench.add("Easter dt zdt v0.4.6", benchEasterv046, .{ .iterations = 50_000 });
    try bench.add("Easter JL zdt v0.4.6", benchEasterJulv046, .{ .iterations = 50_000 });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
