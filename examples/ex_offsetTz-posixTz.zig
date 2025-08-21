const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Timezone = zdt.Timezone;
const UTCoffset = zdt.UTCoffset;

pub fn main() !void {
    println("---> UTC offset example", .{});

    const offset = try UTCoffset.fromSeconds(3600, "UTC+1", false);
    var a_date = try Datetime.fromFields(.{ .year = 1970, .hour = 1, .tz_options = .{ .utc_offset = offset } });
    println("datetime: {f}", .{a_date});
    println("offset name: {s}", .{a_date.tzAbbreviation()});

    const other_offset = try UTCoffset.fromSeconds(-5 * 3600, "UTC-5", false);
    var a_date_other_tz = try a_date.tzConvert(.{ .utc_offset = other_offset });
    println("datetime in other tz: {f}", .{a_date_other_tz});
    println("other offset name: {s}", .{a_date_other_tz.tzAbbreviation()});

    println("\n---> POSIX TZ example", .{});
    const posixTz = try Timezone.fromPosixTz("GMT0BST-1,M3.5.0/1:00,M10.5.0/2:00");
    var a_date_posix_tz = try a_date.tzConvert(.{ .tz = &posixTz });
    println("datetime in POSIX tz: {f}", .{a_date_posix_tz});
    println("  posix tz name: {s}", .{a_date_posix_tz.tzName()});
    println("  posix tz offset name: {s}", .{a_date_posix_tz.tzAbbreviation()});

    const another_date = try Datetime.fromFields(.{ .year = 1970, .month = 8, .tz_options = .{ .tz = &posixTz } });
    println("another datetime in POSIX tz: {f}", .{another_date});
    println("  posix tz name: {s}", .{another_date.tzName()});
    println("  posix tz offset name: {s}", .{another_date.tzAbbreviation()});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    var writer = &stdout.interface;
    writer.print(fmt ++ "\n", args) catch return;
}
