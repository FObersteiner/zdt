const std = @import("std");
const cal = @import("./calendar.zig");
const zbench = @import("zbench");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("\nGPA deinit output: {}\n", .{gpa.deinit()});

    var resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    var bench = try zbench.Benchmark.init("rd-days to date: Neri-Schneider", gpa.allocator());
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_dateFromUnix_NeriSchneider, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("rd-days to date: Hinnant", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_dateFromUnix_Hinnant, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("date to rd-days: Neri-Schneider", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_unixFromDate_NeriSchneider, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("date to rd-days: Hinnant", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_unixFromDate_Hinnant, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("isLeapYear: std lib", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_isLeap_std, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();

    resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(gpa.allocator());
    bench = try zbench.Benchmark.init("isLeapYear: Neri-Schneider", gpa.allocator());
    benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    try zbench.run(bench_isLeap_NeriSchneider, &bench, &benchmarkResults);
    benchmarkResults.results.deinit();
}

fn bench_dateFromUnix_Hinnant(_: *zbench.Benchmark) void {
    var tmp: [3]u16 = undefined;
    var j: i32 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = cal.dateFromUnixdays(j);
        std.mem.doNotOptimizeAway(tmp);
    }
}

fn bench_unixFromDate_Hinnant(_: *zbench.Benchmark) void {
    var tmp: i32 = undefined;
    var j: u16 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = cal.unixdaysFromDate([3]u16{ j, 1, 1 });
        std.mem.doNotOptimizeAway(tmp);
    }
}

fn bench_dateFromUnix_NeriSchneider(_: *zbench.Benchmark) void {
    var tmp: [3]u16 = undefined;
    var j: i32 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = cal.rdToDate(j);
        std.mem.doNotOptimizeAway(tmp);
    }
}

fn bench_unixFromDate_NeriSchneider(_: *zbench.Benchmark) void {
    var tmp: i32 = undefined;
    var j: u16 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = cal.dateToRD([3]u16{ j, 1, 1 });
        std.mem.doNotOptimizeAway(tmp);
    }
}

fn bench_isLeap_std(_: *zbench.Benchmark) void {
    var tmp: bool = undefined;
    var j: u16 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = std.time.epoch.isLeapYear(j);
        std.mem.doNotOptimizeAway(tmp);
    }
}
fn bench_isLeap_NeriSchneider(_: *zbench.Benchmark) void {
    var tmp: bool = undefined;
    var j: u16 = 1;
    while (j < 10_000) : (j += 1) {
        tmp = cal.isLeapYear(j);
        std.mem.doNotOptimizeAway(tmp);
    }
}
