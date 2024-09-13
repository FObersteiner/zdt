const std = @import("std");
const zdt = @import("zdt");

pub fn main() !void {
    // need an allocator for the time zones since the size of the rule-files varies
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tz_LA = try zdt.Timezone.fromTzfile("America/Los_Angeles", allocator);
    defer tz_LA.deinit();
    var tz_Paris = try zdt.Timezone.fromTzfile("Europe/Paris", allocator);
    defer tz_Paris.deinit();

    // ISO8601 parser on-board, accepts wide variety of compatible formats
    const a_datetime = try zdt.parseISO8601("2022-03-07");
    const this_time_LA = try a_datetime.tzLocalize(tz_LA);

    // string output also requires allocation...
    var formatted = std.ArrayList(u8).init(allocator);
    defer formatted.deinit();
    try zdt.formatToString(formatted.writer(), "%I %p, %Z", this_time_LA);

    const this_time_Paris = try this_time_LA.tzConvert(tz_Paris);

    // '{s}' directive gives ISO8601 format by default;
    std.debug.print(
        "Time, LA : {s} ({s})\n... that's {s} in Paris\n\n",
        .{ this_time_LA, formatted.items, this_time_Paris },
    );
    // Time, LA : 2022-03-07T00:00:00-08:00 (12 am, PST)
    // ... that's 2022-03-07T09:00:00+01:00 in Paris

    const wall_diff = try this_time_Paris.diffWall(this_time_LA);
    const abs_diff = this_time_Paris.diff(this_time_LA);

    std.debug.print(
        "Wall clock time difference: {s}\nAbsolute time difference: {s}\n",
        .{ wall_diff, abs_diff },
    );
    // Wall clock time difference: PT09H00M00S
    // Absolute time difference: PT00H00M00S
}
