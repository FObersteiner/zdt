const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Timezone = zdt.Timezone;

pub fn main() !void {
    println("---> duration example", .{});

    const now_utc = Datetime.nowUTC();
    println("now, UTC : {s}", .{now_utc});
    const past_midnight = try now_utc.floorTo(Duration.Timespan.day);

    // difference between two datetimes expressed as Duration:
    println(
        "{d:.3} seconds have passed since midnight ({s})\n",
        .{ now_utc.diff(past_midnight).totalSeconds(), past_midnight },
    );

    // Durations from Timespans:
    const tomorrow = try now_utc.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    println("tomorrow, same time : {s}", .{tomorrow});
    println("tomorrow, same time, is {d} seconds away from now\n", .{tomorrow.diff(now_utc).asSeconds()});

    // Timespan units range from nanoseconds to weeks:
    const two_weeks_ago = try now_utc.sub(Duration.fromTimespanMultiple(2, Duration.Timespan.week));
    println("two weeks ago : {s}", .{two_weeks_ago});

    // ISO8601-duration parser on-board:
    const one_wk_one_h = try Duration.fromISO8601("P7DT1H");
    const in_a_week = try now_utc.add(one_wk_one_h);
    println("in a week and an hour : {s}\n", .{in_a_week});

    // wall-time arithmetic across DST transition using Duration.RelativeDelta:
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var tz_berlin: Timezone = try Timezone.fromTzdata("Europe/Berlin", allocator);
    defer tz_berlin.deinit();

    const delta = try Duration.RelativeDelta.fromISO8601("P1D");
    const dt_dst_off = try Datetime.fromFields(.{ .year = 2024, .month = 3, .day = 30, .hour = 8, .tz_options = .{ .tz = &tz_berlin } });
    const dt_dst_on = try dt_dst_off.addRelative(delta);
    println("{s} --> {s}", .{ dt_dst_off, dt_dst_on });
    println("wall diff: {s}, absolute diff: {s}", .{ try dt_dst_on.diffWall(dt_dst_off), dt_dst_on.diff(dt_dst_off) });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
