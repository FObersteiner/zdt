const std = @import("std");
const print = std.debug.print;

const zdt = @import("zdt");
const dt = zdt.datetime;
const tz = zdt.tz;
const dtstr = zdt.str;

test "offset demo" {
    print("\n---> UTC offset time zone demo", .{});

    const tzinfo = try tz.fromOffset(3600, "UTC+1");
    const a_date = try dt.Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    print("\ndatetime: {s}", .{a_date});
    print("\ntz name: {s}", .{a_date.tzinfo.?.name});

    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    try dtstr.formatDatetime(s.writer(), "%Y-%m-%d", a_date);
    print("\nformatted date-only: {s}\n", .{s.items});

    const other_tzinfo = try tz.fromOffset(-5 * 3600, "UTC-5");
    const a_date_other_tz = try a_date.tzConvert(other_tzinfo);
    print("\ndatetime in other tz: {s}", .{a_date_other_tz});
    print("\nother tz name: {s}", .{a_date_other_tz.tzinfo.?.name});
    s.clearAndFree();
    try dtstr.formatDatetime(s.writer(), "%Y-%m-%d, %Hh", a_date_other_tz);
    print("\nformatted: {s}\n", .{s.items});
}
