const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;

pub fn main() !void {
    println("---> datetime example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    println("datetime type info:", .{});
    println("size of {s}: {}", .{ @typeName(Datetime), @sizeOf(Datetime) });
    inline for (std.meta.fields(Datetime)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Datetime, field.name) });
    }
    println("", .{});

    println("---> (usage) Unix epoch: datetime from timestamp", .{});
    const unix_epoch_naive = try Datetime.fromUnix(0, Duration.Resolution.second, null);
    println("'Unix epoch', naive datetime : {s}", .{unix_epoch_naive});
    var unix_epoch_correct = try Datetime.fromUnix(0, Duration.Resolution.second, .{ .tz = &Tz.UTC });
    println("'Unix epoch', aware datetime : {s}", .{unix_epoch_correct});
    println("'Unix epoch', tz name : {s}", .{unix_epoch_correct.tzName()});

    println("", .{});
    println("---> (usage) Now: datetime from system time", .{});
    const now = Datetime.nowUTC();
    println("'now', UTC      : {s}", .{now});
    println("'now', UTC      : {s:.3} (only ms shown)", .{now});
    const now_s = try now.floorTo(Duration.Timespan.second);
    println("(nanos removed) : {s}", .{now_s});
    const now_date = try now.floorTo(Duration.Timespan.day);
    println("         (date) : {s}", .{now_date});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
