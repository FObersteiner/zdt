const std = @import("std");

const zbench = @import("zbench");

const zdt_030 = @import("zdt_030");
const zdt_045 = @import("zdt_045");

const pbs = @import("parser_isoformat.zig");

fn benchParseISOv030(_: std.mem.Allocator) void {
    _ = zdt_030.parseISO8601(pbs.str) catch unreachable;
}

fn benchParseISOv045(_: std.mem.Allocator) void {
    _ = zdt_045.Datetime.fromISO8601(pbs.str) catch unreachable;
}

pub fn main() !void {
    _ = try pbs.run_isoparse_bench_simple();

    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("parse iso zdt v0.3.0", benchParseISOv030, .{ .iterations = 50_000 });
    try bench.add("parse iso zdt v0.4.5", benchParseISOv045, .{ .iterations = 50_000 });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
