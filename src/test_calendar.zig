//! test calendaric calculations
const std = @import("std");
const testing = std.testing;
const cal = @import("calendar.zig");

test "days_in_month" {
    var d = cal.days_in_month(2, std.time.epoch.isLeapYear(2020));
    try testing.expect(d == 29);
    d = cal.days_in_month(2, std.time.epoch.isLeapYear(2023));
    try testing.expect(d == 28);
    d = cal.days_in_month(12, std.time.epoch.isLeapYear(2023));
    try testing.expect(d == 31);
}

test "unix-days_from_ymd" {
    var days = cal.unixdaysFromDate([_]u16{ 1970, 1, 1 });
    var want: i32 = 0;
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 1969, 12, 27 });
    want = -5;
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 1, 1, 1 });
    want = -719162;
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 2023, 10, 23 });
    want = 19653;
    try testing.expect(days == want);

    // the day may overflow
    days = cal.unixdaysFromDate([_]u16{ 1969, 12, 32 });
    want = 0;
    try testing.expect(days == want);
    days = cal.unixdaysFromDate([_]u16{ 2020, 1, 31 + 29 });
    want = 18321;
    try testing.expect(days == want);
    // month my overflow as well
    days = cal.unixdaysFromDate([_]u16{ 1969, 13, 1 });
    want = 0;
    try testing.expect(days == want);
}

test "ymd_from_unix-days" {
    var date = cal.dateFromUnixdays(0);
    var want = [_]u16{ 1970, 1, 1 };
    for (0.., date) |i, value| {
        try testing.expect(value == want[i]);
    }

    date = cal.dateFromUnixdays(-719162);
    want = [_]u16{ 1, 1, 1 };
    for (0.., date) |i, value| {
        try testing.expect(value == want[i]);
    }

    date = cal.dateFromUnixdays(19653);
    want = [_]u16{ 2023, 10, 23 };
    for (0.., date) |i, value| {
        try testing.expect(value == want[i]);
    }
}
