const std = @import("std");

// const zbench = @import("zbench");
const zeit = @import("zeit");

// const zdt_023 = @import("zdt_023");
// const zdt_045 = @import("zdt_045");
const zdt_current = @import("zdt_current");

const pbs = @import("parser_isoformat.zig");

// fn benchParseISOv023(_: std.mem.Allocator) void {
//     _ = zdt_023.parseISO8601(pbs.str) catch unreachable;
// }
//
// fn benchParseISOv045(_: std.mem.Allocator) void {
//     _ = zdt_045.Datetime.fromISO8601(pbs.str) catch unreachable;
// }

fn benchParseISOcurrentvers(_: std.mem.Allocator) void {
    _ = zdt_current.Datetime.fromISO8601(pbs.str) catch unreachable;
}

fn benchParseISOzeit(_: std.mem.Allocator) void {
    const t = zeit.instant(.{
        .source = .{ .iso8601 = pbs.str },
    }) catch unreachable;
    _ = t.time();
}

fn benchEasterv046(_: std.mem.Allocator) void {
    _ = zdt_current.Datetime.EasterDate(2025) catch unreachable;
}

fn benchEasterJulv046(_: std.mem.Allocator) void {
    _ = zdt_current.Datetime.EasterDateJulian(2025) catch unreachable;
}

pub fn main() !void {
    _ = try pbs.run_isoparse_bench_simple();

    // const stdout = std.io.getStdOut().writer();
    // var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    // defer bench.deinit();
    //
    // try bench.add("parse iso zdt v0.2.3", benchParseISOv023, .{ .iterations = pbs.N });
    // try bench.add("parse iso zdt v0.4.5", benchParseISOv045, .{ .iterations = pbs.N });
    // try bench.add("parse iso zdt latest", benchParseISOcurrentvers, .{ .iterations = pbs.N });
    // try bench.add("parse iso zeit 0.4.4", benchParseISOzeit, .{ .iterations = pbs.N });
    // try bench.add("\nEaster dt zdt latest", benchEasterv046, .{ .iterations = pbs.N });
    // try bench.add("Easter JL zdt latest", benchEasterJulv046, .{ .iterations = pbs.N });
    //
    // try stdout.writeAll("\n");
    // try bench.run(stdout);
}
