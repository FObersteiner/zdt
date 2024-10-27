const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const UTCoffset = zdt.UTCoffset;

pub fn main() !void {
    println("---> UTC offset time zone example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    const offset = try UTCoffset.fromSeconds(3600, "UTC+1");
    var a_date = try Datetime.fromFields(.{ .year = 1970, .tz_options = .{ .utc_offset = offset } });
    println("datetime: {s}", .{a_date});
    println("offset name: {s}", .{a_date.tzAbbreviation()});

    const other_offset = try UTCoffset.fromSeconds(-5 * 3600, "UTC-5");
    var a_date_other_tz = try a_date.tzConvert(.{ .utc_offset = other_offset });
    println("datetime in other tz: {s}", .{a_date_other_tz});
    println("other offset name: {s}", .{a_date_other_tz.tzAbbreviation()});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
