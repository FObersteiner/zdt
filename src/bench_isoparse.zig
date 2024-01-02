const std = @import("std");
const datetime = @import("datetime.zig");
const str = @import("stringIO.zig");
const zbench = @import("zbench");

fn parse_comptime(_: *zbench.Benchmark) void {
    var dt: datetime.Datetime = undefined;
    const fmt = "%Y-%m-%d %H:%M:%S.%f%z";
    var j: i32 = 1;
    while (j < 1000) : (j += 1) {
        dt = str.parseDatetime(fmt, "2014-08-23 12:15:56.000000099Z") catch .{};
        std.mem.doNotOptimizeAway(dt);
    }
}

fn parse_runtime(_: *zbench.Benchmark) void {
    var dt: datetime.Datetime = undefined;
    var j: u16 = 1;
    while (j < 1000) : (j += 1) {
        dt = str.parseISO8601("2014-08-23 12:15:56.000000099Z") catch .{};
        std.mem.doNotOptimizeAway(dt);
    }
}

test "parse ISO with prescribed format" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Parse 1k with comptime format", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(parse_comptime, &bench, &benchmarkResults);
}

test "parse ISO with runtime parser" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Parse 1k with runtime parser", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(parse_runtime, &bench, &benchmarkResults);
}
