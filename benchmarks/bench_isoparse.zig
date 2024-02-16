const std = @import("std");
const Datetime = @import("./Datetime.zig");
const str = @import("./stringIO.zig");
const zbench = @import("zbench");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("\nGPA deinit output: {}\n", .{gpa.deinit()});

    var resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    var bench = try zbench.Benchmark.init("Parse 1k with comptime format", gpa.allocator());
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(parse_comptime, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("Parse 1k with runtime parser", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(parse_runtime, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();
}

fn parse_comptime(_: *zbench.Benchmark) void {
    var dt: Datetime = undefined;
    const fmt = "%Y-%m-%d %H:%M:%S.%f%z";
    var j: i32 = 1;
    while (j < 1000) : (j += 1) {
        dt = str.parseDatetime(fmt, "2014-08-23 12:15:56.000000099Z") catch .{};
        std.mem.doNotOptimizeAway(dt);
    }
}

fn parse_runtime(_: *zbench.Benchmark) void {
    var dt: Datetime = undefined;
    var j: u16 = 1;
    while (j < 1000) : (j += 1) {
        dt = str.parseISO8601("2014-08-23 12:15:56.000000099Z") catch .{};
        std.mem.doNotOptimizeAway(dt);
    }
}
