const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");

pub fn main() !void {
    println("---> duration example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    println("Duration type info:", .{});
    println("size of {s}: {}", .{ @typeName(zdt.Duration), @sizeOf(zdt.Duration) });
    inline for (std.meta.fields(zdt.Duration)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(zdt.Duration, field.name) });
    }
    println("", .{});

    const now_utc = zdt.Datetime.nowUTC();
    println("now, UTC : {s}", .{now_utc});
    const past_midnight = try now_utc.floorTo(zdt.Duration.Timespan.day);
    println(
        "{d:.3} seconds have passed since midnight ({s})\n",
        .{ now_utc.diff(past_midnight).totalSeconds(), past_midnight },
    );

    const tomorrow = try now_utc.add(zdt.Duration.fromTimespanMultiple(1, zdt.Duration.Timespan.day));
    println("tomorrow, same time : {s}", .{tomorrow});
    println("tomorrow, same time, is {d} seconds away from now\n", .{tomorrow.diff(now_utc).asSeconds()});

    const two_weeks_ago = try now_utc.sub(zdt.Duration.fromTimespanMultiple(2, zdt.Duration.Timespan.week));
    println("two weeks ago : {s}", .{two_weeks_ago});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
