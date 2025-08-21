const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Timezone = zdt.Timezone;

pub fn main() !void {
    println("---> datetime strings example", .{});

    // the easiest input format is probably ISO8601. This can directly
    // be parsed; schema is infered at runtime.
    println("", .{});
    println("---> (usage) ISO8601: parse some allowed formats", .{});
    const date_only = "2014-08-23";
    var parsed = try Datetime.fromISO8601(date_only);
    assert(parsed.hour == 0);
    println("parsed '{s}'\n  to {f}", .{ date_only, parsed });
    // the default string representation of a zdt.Datetime instance is always ISO8601

    // we can have fractional seconds:
    const datetime_with_frac = "2014-08-23 12:15:56.123456789";
    parsed = try Datetime.fromISO8601(datetime_with_frac);
    assert(parsed.nanosecond == 123456789);
    println("parsed '{s}'\n  to {f}", .{ datetime_with_frac, parsed });

    // we can also have a leap second, and a time zone specifier (Z == UTC):
    const leap_datetime = "2016-12-31T23:59:60Z";
    parsed = try Datetime.fromISO8601(leap_datetime);
    assert(parsed.second == 60);
    assert(std.meta.eql(parsed.tz.?.*, Timezone.UTC));
    println("parsed '{s}'\n  to {f}", .{ leap_datetime, parsed });

    // The format might be less-standard, so we need to provide parsing directives à la strptime
    println("", .{});
    println("---> (usage): parse some non-standard format", .{});
    const dayfirst_dtstr = "23.7.2021, 9:45h";
    parsed = try Datetime.fromString(dayfirst_dtstr, "%d.%m.%Y, %H:%Mh");
    // zdt.Datetime.strptime is also available for people used to strftime/strptime
    assert(parsed.day == 23);
    println("parsed '{s}'\n  to {f}", .{ dayfirst_dtstr, parsed });

    // We can also go the other way around. Since the output is a runtime-known
    // and we don't want to loose bytes in temporary memory, we use an allocator.
    println("", .{});
    println("---> (usage): format datetime to string", .{});

    var buf: [32]u8 = std.mem.zeroes([32]u8);
    var w = std.Io.Writer.fixed(&buf);
    try parsed.toString("%a, %b %d %Y, %H:%Mh", &w);
    println("formatted {f}\n  to '{s}'", .{ parsed, buf });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    var writer = &stdout.interface;
    writer.print(fmt ++ "\n", args) catch return;
}
