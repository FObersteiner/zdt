const std = @import("std");
const cal = @import("calendar.zig");
const zbench = @import("zbench");

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

test "bench Neri-Schneider, days -> date" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Neri-Schneider, rd to date", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_dateFromUnix_NeriSchneider, &bench, &benchmarkResults);
}

test "bench Neri-Schneider, date -> days" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Neri-Schneider, date to rd", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_unixFromDate_NeriSchneider, &bench, &benchmarkResults);
}

test "bench Hinnant, days -> date" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Hinnant, days to civil", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_dateFromUnix_Hinnant, &bench, &benchmarkResults);
}

test "bench Hinnant, date -> days" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("Hinnant, civil to days", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_unixFromDate_Hinnant, &bench, &benchmarkResults);
}

test "bench isLeap, std lib" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("isLeapYear, std lib", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_isLeap_std, &bench, &benchmarkResults);
}

test "bench isLeap, Neri-Schneider" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(std.testing.allocator);
    var bench = try zbench.Benchmark.init("isLeapYear, Neri-Schneider", std.testing.allocator);
    var benchmarkResults = zbench.BenchmarkResults{ .results = resultsAlloc };
    defer benchmarkResults.results.deinit();
    try zbench.run(bench_isLeap_NeriSchneider, &bench, &benchmarkResults);
}
