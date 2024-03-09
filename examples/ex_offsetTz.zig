const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Tz = zdt.Timezone;
const str = zdt.stringIO;

pub fn main() !void {
    println("---> UTC offset time zone example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    const tzinfo = try Tz.fromOffset(3600, "UTC+1");
    var a_date = try Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    println("datetime: {s}", .{a_date});
    println("tz name: {s}", .{a_date.tzinfo.?.name()});

    const other_tzinfo = try Tz.fromOffset(-5 * 3600, "UTC-5");
    var a_date_other_tz = try a_date.tzConvert(other_tzinfo);
    println("datetime in other tz: {s}", .{a_date_other_tz});
    println("other tz name: {s}", .{a_date_other_tz.tzinfo.?.name()});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
