const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");

pub fn main() !void {
    // Can use an allocator for the time zones as the size of the rule-files varies.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // zdt embeds the IANA tz database (about 700k of raw data).
    // If you pass null instead of the allocator, a fixed-size structure will be used - faster, but more mem required.
    var tz_LA = try zdt.Timezone.fromTzdata("America/Los_Angeles", allocator);
    defer tz_LA.deinit();

    // You can also use your system's tz data at runtime;
    // this will very likely not work on Windows, so we use the embedded version here as well.
    var tz_Paris = switch (builtin.os.tag) {
        .windows => try zdt.Timezone.fromTzdata("Europe/Paris", allocator),
        else => try zdt.Timezone.fromSystemTzdata("Europe/Paris", zdt.Timezone.tzdb_prefix, allocator),
    };
    defer tz_Paris.deinit();

    // ISO8601 parser on-board, accepts wide variety of compatible formats
    const a_datetime = try zdt.Datetime.fromISO8601("2022-03-07");
    const this_time_LA = try a_datetime.tzLocalize(.{ .tz = &tz_LA });

    // string output also requires allocation...
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try this_time_LA.toString("%I %p, %Z", buf.writer());

    const this_time_Paris = try this_time_LA.tzConvert(.{ .tz = &tz_Paris });

    // '{s}' directive gives ISO8601 format by default;
    std.debug.print(
        "Time, LA : {s} ({s})\n... that's {s} in Paris ({s})\n\n",
        .{ this_time_LA, buf.items, this_time_Paris, this_time_Paris.tzAbbreviation() },
    );
    // Time, LA : 2022-03-07T00:00:00-08:00 (12 am, PST)
    // ... that's 2022-03-07T09:00:00+01:00 in Paris

    const wall_diff = try this_time_Paris.diffWall(this_time_LA);
    const abs_diff = this_time_Paris.diff(this_time_LA);

    std.debug.print("Wall clock time difference: {s}\nAbsolute time difference: {s}\n\n", .{ wall_diff, abs_diff });
    // Wall clock time difference: PT9H
    // Absolute time difference: PT0S

    // Easteregg:
    std.debug.print(
        "Easter this year is on {%B %d, %Y}\n",
        .{try zdt.Datetime.EasterDate(zdt.Datetime.nowUTC().year)},
    );
    // Easter this year is on April 20, 2025
}
