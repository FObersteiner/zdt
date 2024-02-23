//! test datetime from a users's perspective (no internal functionality)
const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const ZdtError = zdt.ZdtError;
const cal = zdt.calendar;

const log = std.log.scoped(.test_datetime);

test "validate datetime fields" {
    var fields = Datetime.Fields{ .year = 2020, .month = 2, .day = 29 };
    try fields.validate();
    fields = Datetime.Fields{ .year = 2023, .month = 2, .day = 29 };
    var err = fields.validate();
    try testing.expectError(ZdtError.DayOutOfRange, err);

    fields = Datetime.Fields{ .year = 2023, .month = 4, .day = 31 };
    err = fields.validate();
    try testing.expectError(ZdtError.DayOutOfRange, err);

    fields = Datetime.Fields{ .year = 2023, .month = 6, .day = 0 };
    err = fields.validate();
    try testing.expectError(ZdtError.DayOutOfRange, err);

    fields = Datetime.Fields{ .year = 2023, .month = 13, .day = 1 };
    err = fields.validate();
    try testing.expectError(ZdtError.MonthOutOfRange, err);

    fields = Datetime.Fields{ .year = 10000, .month = 1, .day = 1 };
    err = fields.validate();
    try testing.expectError(ZdtError.YearOutOfRange, err);

    fields = Datetime.Fields{ .hour = 99 };
    err = fields.validate();
    try testing.expectError(ZdtError.HourOutOfRange, err);

    fields = Datetime.Fields{ .minute = 99 };
    err = fields.validate();
    try testing.expectError(ZdtError.MinuteOutOfRange, err);

    fields = Datetime.Fields{ .second = 99 };
    err = fields.validate();
    try testing.expectError(ZdtError.SecondOutOfRange, err);
}

test "validate tz field" {
    const undef = Tz{};
    const fields = Datetime.Fields{ .year = 1, .month = 1, .day = 1, .tzinfo = undef };
    const err = fields.validate();
    try testing.expectError(ZdtError.AllTZRulesUndefined, err);
}

test "Datetime from empty field struct" {
    const dt = try Datetime.fromFields(.{});
    try testing.expectEqual(@as(u14, 1), dt.year);
    try testing.expectEqual(@as(u4, 1), dt.month);
    try testing.expectEqual(@as(u5, 1), dt.day);
    try testing.expect(dt.tzinfo == null);
}

test "Datetime from populated field struct" {
    const dt = try Datetime.fromFields(.{ .year = 2023, .month = 12 });
    try testing.expectEqual(@as(u14, 2023), dt.year);
    try testing.expectEqual(@as(u4, 12), dt.month);
    try testing.expectEqual(@as(u5, 1), dt.day);
    try testing.expect(dt.tzinfo == null);
}

test "Datetime from list" {
    const dt = try Datetime.fromFields(.{ .year = 2023, .month = 12 });
    try testing.expectEqual(@as(u14, 2023), dt.year);
    try testing.expectEqual(@as(u4, 12), dt.month);
    try testing.expectEqual(@as(u5, 1), dt.day);
    try testing.expect(dt.tzinfo == null);
}

test "Datetime Unix epoch roundtrip" {
    var unix_from_fields = try Datetime.fromFields(.{ .year = 1970, .second = 42 });
    var unix_from_int = try Datetime.fromUnix(42, Duration.Resolution.second, null);
    try testing.expect(std.meta.eql(unix_from_fields, unix_from_int));
    var unix_s = unix_from_int.toUnix(Duration.Resolution.second);
    try testing.expect(unix_s == 42);

    unix_from_fields = try Datetime.fromFields(.{ .year = 1970, .second = 42, .nanosecond = 1_000_000 });
    unix_from_int = try Datetime.fromUnix(42001, Duration.Resolution.millisecond, null);
    try testing.expect(std.meta.eql(unix_from_fields, unix_from_int));
    unix_s = unix_from_int.toUnix(Duration.Resolution.millisecond);
    try testing.expect(unix_s == 42001);

    unix_from_fields = try Datetime.fromFields(.{ .year = 1970, .second = 42, .nanosecond = 1_001_000 });
    unix_from_int = try Datetime.fromUnix(42001001, Duration.Resolution.microsecond, null);
    try testing.expect(std.meta.eql(unix_from_fields, unix_from_int));
    unix_s = unix_from_int.toUnix(Duration.Resolution.microsecond);
    try testing.expect(unix_s == 42001001);

    unix_from_fields = try Datetime.fromFields(.{ .year = 1970, .second = 42, .nanosecond = 1_001_001 });
    unix_from_int = try Datetime.fromUnix(42001001001, Duration.Resolution.nanosecond, null);
    try testing.expect(std.meta.eql(unix_from_fields, unix_from_int));
    unix_s = unix_from_int.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix_s == 42001001001);
}

test "Fields can represent leap second, Unix cannot" {
    const dt_from_fields = try Datetime.fromFields(.{ .year = 1970, .second = 60 });
    try testing.expectEqual(@as(u6, 60), dt_from_fields.second);
    const unix_s = dt_from_fields.toUnix(Duration.Resolution.second);
    try testing.expectEqual(@as(i72, 59), unix_s);

    const dt_from_int = try Datetime.fromUnix(60, Duration.Resolution.second, null);
    try testing.expectEqual(@as(u6, 0), dt_from_int.second);
    try testing.expectEqual(@as(u6, 1), dt_from_int.minute);
}

test "Dateime from invalid fields" {
    var fields = Datetime.Fields{ .year = 2021, .month = 2, .day = 29 };
    var err = Datetime.fromFields(fields);
    try testing.expectError(ZdtError.DayOutOfRange, err);

    fields = Datetime.Fields{ .year = 1, .month = 1, .day = 1, .nanosecond = 1000000000 };
    err = Datetime.fromFields(fields);
    try testing.expectError(ZdtError.NanosecondOutOfRange, err);
}

test "Datetime Min Max from fields" {
    var fields = Datetime.Fields{ .year = Datetime.min_year, .month = 1, .day = 1 };
    var dt = try Datetime.fromFields(fields);
    try testing.expect(dt.year == Datetime.min_year);
    try testing.expect(dt.__unix == Datetime.unix_s_min);

    fields = Datetime.Fields{ .year = Datetime.max_year, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 59, .nanosecond = 999999999 };
    dt = try Datetime.fromFields(fields);
    try testing.expect(dt.year == Datetime.max_year);
    try testing.expect(dt.hour == 23);
    try testing.expectEqual(Datetime.unix_s_max, dt.__unix);
}

test "Datetime Min Max fields vs seconds roundtrip" {
    const max_from_seconds = try Datetime.fromUnix(Datetime.unix_s_max, Duration.Resolution.second, null);
    const max_from_fields = try Datetime.fromFields(.{ .year = Datetime.max_year, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 59 });
    try testing.expect(std.meta.eql(max_from_fields, max_from_seconds));

    const min_from_fields = try Datetime.fromFields(.{ .year = 1 });
    const min_from_seconds = try Datetime.fromUnix(Datetime.unix_s_min, Duration.Resolution.second, null);
    try testing.expect(std.meta.eql(min_from_fields, min_from_seconds));

    const too_large_s = Datetime.fromUnix(Datetime.unix_s_max + 1, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_large_s);
    const too_large_ns = Datetime.fromUnix(@as(i72, Datetime.unix_s_max + 1) * std.time.ns_per_s, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_large_ns);
    const too_small_s = Datetime.fromUnix(Datetime.unix_s_min - 1, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_small_s);
    const too_small_ns = Datetime.fromUnix(@as(i72, Datetime.unix_s_min - 1) * std.time.ns_per_s, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_small_ns);
}

test "Epoch" {
    var epoch = Datetime.epoch;
    try testing.expectEqual(epoch.year, 1970);
    try testing.expectEqual(epoch.month, 1);
    try testing.expectEqual(epoch.day, 1);
    try testing.expectEqual(epoch.__unix, 0);
    try testing.expectEqualStrings(epoch.tzinfo.?.abbreviation(), "Z");
    try testing.expectEqualStrings(epoch.tzinfo.?.name(), "UTC");
}

test "default format ISO8601, naive" {
    var str = std.ArrayList(u8).init(testing.allocator);
    defer str.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 31 });
    try dt.format("", .{}, str.writer());
    try testing.expectEqualStrings("2023-12-31T00:00:00", str.items);

    str.clearRetainingCapacity();
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 31, .nanosecond = 1 });
    try dt.format("", .{}, str.writer());
    try testing.expectEqualStrings("2023-12-31T00:00:00.000000001", str.items);
}

test "format offset" {
    var tzinfo = try Tz.fromOffset(3600, "");
    var dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });

    var str = std.ArrayList(u8).init(testing.allocator);
    try dt.formatOffset(str.writer());
    try testing.expectEqualStrings("+01:00", str.items);
    str.deinit();

    tzinfo = try Tz.fromOffset(3600 * 9 + 942, "");
    dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    str = std.ArrayList(u8).init(testing.allocator);
    try dt.formatOffset(str.writer());
    try testing.expectEqualStrings("+09:15:42", str.items);
    str.deinit();
}

test "default format ISO8601, with offset" {
    var str = std.ArrayList(u8).init(testing.allocator);
    defer str.deinit();
    const offset: i32 = 3600;
    const tzinfo = try Tz.fromOffset(offset, "");
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    try dt.format("", .{}, str.writer());
    try testing.expectEqualStrings("2021-02-18T17:00:00+01:00", str.items);
}

test "compare Unix time" {
    const offset: i32 = 3600;
    const tzinfo = try Tz.fromOffset(offset, "");
    var a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const b = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .tzinfo = null });

    var err = Datetime.compareUT(a, b);
    try testing.expectError(ZdtError.CompareNaiveAware, err);
    err = Datetime.compareUT(b, a);
    try testing.expectError(ZdtError.CompareNaiveAware, err);

    var want_eq = try Datetime.compareUT(a, a);
    try testing.expectEqual(std.math.Order.eq, want_eq);
    want_eq = try Datetime.compareUT(b, b);
    try testing.expectEqual(std.math.Order.eq, want_eq);

    a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = null });
    const want_lt = try Datetime.compareUT(a, b);
    try testing.expectEqual(std.math.Order.lt, want_lt);
    const want_gt = try Datetime.compareUT(b, a);
    try testing.expectEqual(std.math.Order.gt, want_gt);
}

test "compare wall time" {
    const offset: i32 = 3600;
    const tzinfo = try Tz.fromOffset(offset, "");
    var a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42, .tzinfo = null });
    const b = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42, .tzinfo = tzinfo });
    try testing.expectEqual(std.math.Order.eq, try Datetime.compareWall(a, b));

    a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 42, .tzinfo = null });
    try testing.expectEqual(std.math.Order.lt, try Datetime.compareWall(a, b));
    try testing.expectEqual(std.math.Order.gt, try Datetime.compareWall(b, a));
}

test "floor naive datetime to the second" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42, .tzinfo = null });
    const dt_floored = try dt.floorTo(Duration.Timespan.second);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(dt_floored.hour, dt.hour);
    try testing.expectEqual(dt_floored.minute, dt.minute);
    try testing.expectEqual(dt_floored.second, dt.second);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
}

test "floor naive datetime to the minute" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42, .tzinfo = null });
    const dt_floored = try dt.floorTo(Duration.Timespan.minute);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(dt_floored.hour, dt.hour);
    try testing.expectEqual(dt_floored.minute, dt.minute);
    try testing.expectEqual(@as(u6, 0), dt_floored.second);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
}

test "floor naive datetime to the hour" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42, .tzinfo = null });
    const dt_floored = try dt.floorTo(Duration.Timespan.hour);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(dt_floored.hour, dt.hour);
    try testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try testing.expectEqual(@as(u6, 0), dt_floored.second);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
}

test "floor naive datetime to the date" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42, .tzinfo = null });
    const dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(@as(u5, 0), dt_floored.hour);
    try testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try testing.expectEqual(@as(u6, 0), dt_floored.second);
    try testing.expectEqual(@as(u30, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(i48, 1613606400), dt_floored.__unix);
}

test "day of year" {
    // leap year
    var dt = try Datetime.fromFields(.{ .year = 2020 });
    var i: u9 = 1;
    while (i < 367) : (i += 1) {
        try testing.expectEqual(i, dt.dayOfYear());
        dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    }
    // normal year
    dt = try Datetime.fromFields(.{ .year = 2021 });
    i = 1;
    while (i < 366) : (i += 1) {
        try testing.expectEqual(i, dt.dayOfYear());
        dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    }
}

test "day of week" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .day = 4 });
    var i: u3 = 0;
    while (i < 7) : (i += 1) {
        try testing.expectEqual(i, dt.weekdayNumber());
        dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    }
}

test "day of week, iso" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .day = 5 });
    var i: u4 = 1;
    while (i < 8) : (i += 1) {
        try testing.expectEqual(i, @as(u4, dt.weekdayIsoNumber()));
        dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    }
}

test "weekday enum" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqual(Datetime.Weekday.Thursday, dt.weekday());
    try testing.expectEqualStrings("Thu", dt.weekday().shortName());
    try testing.expectEqualStrings("Thursday", dt.weekday().longName());
}

test "month enum" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqualStrings("Jan", dt.monthEnum().shortName());
    try testing.expectEqualStrings("January", dt.monthEnum().longName());
}

test "next weekday" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    const nextThu = dt.nextWeekday(Datetime.Weekday.Thursday);
    try testing.expectEqualStrings("Thursday", nextThu.weekday().longName());
    try testing.expectEqual(@as(u6, 8), nextThu.day);

    const nextWed = dt.nextWeekday(Datetime.Weekday.Wednesday);
    try testing.expectEqualStrings("Wednesday", nextWed.weekday().longName());
    try testing.expectEqual(@as(u6, 7), nextWed.day);

    const nextSun = dt.nextWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqualStrings("Sunday", nextSun.weekday().longName());
    try testing.expectEqual(@as(u6, 4), nextSun.day);
}

test "prev weekday" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    const prevThu = dt.previousWeekday(Datetime.Weekday.Thursday);
    try testing.expectEqualStrings("Thursday", prevThu.weekday().longName());
    try testing.expectEqual(@as(u6, 25), prevThu.day);

    const prevWed = dt.previousWeekday(Datetime.Weekday.Wednesday);
    try testing.expectEqualStrings("Wednesday", prevWed.weekday().longName());
    try testing.expectEqual(@as(u6, 31), prevWed.day);

    const prevSun = dt.previousWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqualStrings("Sunday", prevSun.weekday().longName());
    try testing.expectEqual(@as(u6, 28), prevSun.day);
}

test "nth weekday" {
    var want_dt = try Datetime.fromFields(.{ .year = 1970 });
    var dt = try Datetime.nthWeekday(1970, 1, Datetime.Weekday.Thursday, 1);
    try testing.expect(std.meta.eql(dt, want_dt));

    want_dt = try Datetime.fromFields(.{ .year = 1970, .day = 8 });
    dt = try Datetime.nthWeekday(1970, 1, Datetime.Weekday.Thursday, 2);
    try testing.expect(std.meta.eql(dt, want_dt));

    want_dt = try Datetime.fromFields(.{ .year = 1970, .day = 29 });
    dt = try Datetime.nthWeekday(1970, 1, Datetime.Weekday.Thursday, 5);
    try testing.expect(std.meta.eql(dt, want_dt));

    want_dt = try Datetime.fromFields(.{ .year = 1970, .day = 7 });
    dt = try Datetime.nthWeekday(1970, 1, Datetime.Weekday.Wednesday, 1);
    try testing.expect(std.meta.eql(dt, want_dt));

    const err = Datetime.nthWeekday(1970, 1, Datetime.Weekday.Wednesday, 5);
    try testing.expectError(ZdtError.DayOutOfRange, err);
}

test "week of year" {
    var dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqual(@as(u6, 0), dt.weekOfYearSun());
    const nextSun = dt.nextWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqual(@as(u6, 1), nextSun.weekOfYearSun());

    try testing.expectEqual(@as(u6, 0), nextSun.weekOfYearMon());
    const nextMon = dt.nextWeekday(Datetime.Weekday.Monday);
    try testing.expectEqual(@as(u6, 1), nextMon.weekOfYearMon());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 31 });
    try testing.expectEqual(@as(u6, 53), dt.weekOfYearSun());
    try testing.expectEqual(@as(u6, 52), dt.weekOfYearMon());
}

test "iso calendar" {
    var dt = try Datetime.fromFields(.{ .year = 2024, .month = 1, .day = 9 });
    var isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 2), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1977, .month = 1, .day = 1 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 53), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1977, .month = 12, .day = 31 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 1, .day = 1 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 1, .day = 2 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 12, .day = 31 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 28 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 29 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 30 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 31 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1980, .month = 1, .day = 1 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1981, .month = 12, .day = 31 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 53), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1982, .month = 1, .day = 3 });
    isocal = dt.isocalendar();
    try testing.expectEqual(@as(u6, 53), isocal.isoweek);
}

// ---vv--- test generated with Python script ---vv---

test "unix nanoseconds, fields" {
    // 1931-10-12T06:52:00.652701+00:00 :
    var dt_from_unix = try Datetime.fromUnix(-1206205679347298795, Duration.Resolution.nanosecond, null);
    var dt_from_fields = try Datetime.fromFields(.{ .year = 1931, .month = 10, .day = 12, .hour = 6, .minute = 52, .second = 0, .nanosecond = 652701205 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    var unix: i72 = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1206205679347298795);

    // 1969-11-24T23:10:10.285143+00:00 :
    dt_from_unix = try Datetime.fromUnix(-3199789714856270, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1969, .month = 11, .day = 24, .hour = 23, .minute = 10, .second = 10, .nanosecond = 285143730 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -3199789714856270);

    // 1939-10-30T19:50:28.445918+00:00 :
    dt_from_unix = try Datetime.fromUnix(-952142971554081681, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1939, .month = 10, .day = 30, .hour = 19, .minute = 50, .second = 28, .nanosecond = 445918319 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -952142971554081681);

    // 1929-04-04T02:38:18.493097+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1285795301506902592, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1929, .month = 4, .day = 4, .hour = 2, .minute = 38, .second = 18, .nanosecond = 493097408 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1285795301506902592);

    // 2055-08-30T11:24:07.794000+00:00 :
    dt_from_unix = try Datetime.fromUnix(2703237847794000687, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2055, .month = 8, .day = 30, .hour = 11, .minute = 24, .second = 7, .nanosecond = 794000687 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2703237847794000687);

    // 2068-07-16T19:35:14.335618+00:00 :
    dt_from_unix = try Datetime.fromUnix(3109692914335618665, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2068, .month = 7, .day = 16, .hour = 19, .minute = 35, .second = 14, .nanosecond = 335618665 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3109692914335618665);

    // 1909-01-27T08:37:47.320729+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1922714532679270618, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1909, .month = 1, .day = 27, .hour = 8, .minute = 37, .second = 47, .nanosecond = 320729382 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1922714532679270618);

    // 1926-09-29T17:18:56.871022+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1365057663128977552, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1926, .month = 9, .day = 29, .hour = 17, .minute = 18, .second = 56, .nanosecond = 871022448 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1365057663128977552);

    // 1966-05-29T21:27:36.943755+00:00 :
    dt_from_unix = try Datetime.fromUnix(-113365943056244079, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1966, .month = 5, .day = 29, .hour = 21, .minute = 27, .second = 36, .nanosecond = 943755921 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -113365943056244079);

    // 2071-10-31T10:24:20.899537+00:00 :
    dt_from_unix = try Datetime.fromUnix(3213512660899537529, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2071, .month = 10, .day = 31, .hour = 10, .minute = 24, .second = 20, .nanosecond = 899537529 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3213512660899537529);

    // 2060-03-11T18:49:00.839859+00:00 :
    dt_from_unix = try Datetime.fromUnix(2846256540839859462, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2060, .month = 3, .day = 11, .hour = 18, .minute = 49, .second = 0, .nanosecond = 839859462 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2846256540839859462);

    // 2019-09-28T22:09:47.657462+00:00 :
    dt_from_unix = try Datetime.fromUnix(1569708587657462123, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2019, .month = 9, .day = 28, .hour = 22, .minute = 9, .second = 47, .nanosecond = 657462123 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1569708587657462123);

    // 2028-03-20T00:25:42.687712+00:00 :
    dt_from_unix = try Datetime.fromUnix(1837124742687712253, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2028, .month = 3, .day = 20, .hour = 0, .minute = 25, .second = 42, .nanosecond = 687712253 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1837124742687712253);

    // 1979-05-28T09:33:31.101612+00:00 :
    dt_from_unix = try Datetime.fromUnix(296732011101612230, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1979, .month = 5, .day = 28, .hour = 9, .minute = 33, .second = 31, .nanosecond = 101612230 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 296732011101612230);

    // 1945-07-28T11:31:05.719741+00:00 :
    dt_from_unix = try Datetime.fromUnix(-770905734280258935, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1945, .month = 7, .day = 28, .hour = 11, .minute = 31, .second = 5, .nanosecond = 719741065 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -770905734280258935);

    // 2020-08-16T13:13:03.388538+00:00 :
    dt_from_unix = try Datetime.fromUnix(1597583583388538346, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2020, .month = 8, .day = 16, .hour = 13, .minute = 13, .second = 3, .nanosecond = 388538346 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1597583583388538346);

    // 1979-04-25T01:55:13.501302+00:00 :
    dt_from_unix = try Datetime.fromUnix(293853313501302021, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1979, .month = 4, .day = 25, .hour = 1, .minute = 55, .second = 13, .nanosecond = 501302021 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 293853313501302021);

    // 1961-06-16T10:21:15.451696+00:00 :
    dt_from_unix = try Datetime.fromUnix(-269617124548303398, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1961, .month = 6, .day = 16, .hour = 10, .minute = 21, .second = 15, .nanosecond = 451696602 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -269617124548303398);

    // 1929-03-05T09:54:45.560185+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1288361114439814433, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1929, .month = 3, .day = 5, .hour = 9, .minute = 54, .second = 45, .nanosecond = 560185567 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1288361114439814433);

    // 2008-06-10T09:46:55.937809+00:00 :
    dt_from_unix = try Datetime.fromUnix(1213091215937809235, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2008, .month = 6, .day = 10, .hour = 9, .minute = 46, .second = 55, .nanosecond = 937809235 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1213091215937809235);

    // 2002-06-18T14:03:44.710551+00:00 :
    dt_from_unix = try Datetime.fromUnix(1024409024710551602, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2002, .month = 6, .day = 18, .hour = 14, .minute = 3, .second = 44, .nanosecond = 710551602 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1024409024710551602);

    // 1998-03-05T09:38:34.682387+00:00 :
    dt_from_unix = try Datetime.fromUnix(889090714682387225, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1998, .month = 3, .day = 5, .hour = 9, .minute = 38, .second = 34, .nanosecond = 682387225 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 889090714682387225);

    // 1975-07-03T07:19:10.766595+00:00 :
    dt_from_unix = try Datetime.fromUnix(173603950766595007, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1975, .month = 7, .day = 3, .hour = 7, .minute = 19, .second = 10, .nanosecond = 766595007 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 173603950766595007);

    // 1912-05-27T17:44:36.535679+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1817619323464320928, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1912, .month = 5, .day = 27, .hour = 17, .minute = 44, .second = 36, .nanosecond = 535679072 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1817619323464320928);

    // 2031-02-18T00:51:49.426128+00:00 :
    dt_from_unix = try Datetime.fromUnix(1929142309426128724, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2031, .month = 2, .day = 18, .hour = 0, .minute = 51, .second = 49, .nanosecond = 426128724 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1929142309426128724);

    // 1935-08-19T03:09:06.861701+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1084654253138298354, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1935, .month = 8, .day = 19, .hour = 3, .minute = 9, .second = 6, .nanosecond = 861701646 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1084654253138298354);

    // 1922-06-29T21:20:46.293267+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1499222353706732940, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1922, .month = 6, .day = 29, .hour = 21, .minute = 20, .second = 46, .nanosecond = 293267060 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1499222353706732940);

    // 1983-09-06T20:09:28.301809+00:00 :
    dt_from_unix = try Datetime.fromUnix(431726968301809234, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1983, .month = 9, .day = 6, .hour = 20, .minute = 9, .second = 28, .nanosecond = 301809234 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 431726968301809234);

    // 2079-06-06T17:23:01.849394+00:00 :
    dt_from_unix = try Datetime.fromUnix(3453297781849394069, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2079, .month = 6, .day = 6, .hour = 17, .minute = 23, .second = 1, .nanosecond = 849394069 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3453297781849394069);

    // 2003-03-22T11:03:03.191233+00:00 :
    dt_from_unix = try Datetime.fromUnix(1048330983191233927, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2003, .month = 3, .day = 22, .hour = 11, .minute = 3, .second = 3, .nanosecond = 191233927 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1048330983191233927);

    // 1954-11-20T02:13:21.558975+00:00 :
    dt_from_unix = try Datetime.fromUnix(-477006398441024968, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1954, .month = 11, .day = 20, .hour = 2, .minute = 13, .second = 21, .nanosecond = 558975032 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -477006398441024968);

    // 1919-11-09T02:57:00.678640+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1582491779321359120, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1919, .month = 11, .day = 9, .hour = 2, .minute = 57, .second = 0, .nanosecond = 678640880 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1582491779321359120);

    // 2088-09-27T15:54:58.920857+00:00 :
    dt_from_unix = try Datetime.fromUnix(3747138898920857338, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2088, .month = 9, .day = 27, .hour = 15, .minute = 54, .second = 58, .nanosecond = 920857338 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3747138898920857338);

    // 2008-07-01T03:17:32.757712+00:00 :
    dt_from_unix = try Datetime.fromUnix(1214882252757712072, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2008, .month = 7, .day = 1, .hour = 3, .minute = 17, .second = 32, .nanosecond = 757712072 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1214882252757712072);

    // 2029-06-01T00:25:46.635065+00:00 :
    dt_from_unix = try Datetime.fromUnix(1874967946635065526, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2029, .month = 6, .day = 1, .hour = 0, .minute = 25, .second = 46, .nanosecond = 635065526 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1874967946635065526);

    // 1946-06-05T16:31:01.280833+00:00 :
    dt_from_unix = try Datetime.fromUnix(-743930938719166757, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1946, .month = 6, .day = 5, .hour = 16, .minute = 31, .second = 1, .nanosecond = 280833243 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -743930938719166757);

    // 2001-05-27T22:52:23.603720+00:00 :
    dt_from_unix = try Datetime.fromUnix(991003943603720285, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2001, .month = 5, .day = 27, .hour = 22, .minute = 52, .second = 23, .nanosecond = 603720285 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 991003943603720285);

    // 2091-04-14T18:09:00.694702+00:00 :
    dt_from_unix = try Datetime.fromUnix(3827412540694702685, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2091, .month = 4, .day = 14, .hour = 18, .minute = 9, .second = 0, .nanosecond = 694702685 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3827412540694702685);

    // 2095-02-06T20:48:46.618697+00:00 :
    dt_from_unix = try Datetime.fromUnix(3947863726618697497, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2095, .month = 2, .day = 6, .hour = 20, .minute = 48, .second = 46, .nanosecond = 618697497 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3947863726618697497);

    // 1920-05-19T16:44:41.161131+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1565853318838868781, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1920, .month = 5, .day = 19, .hour = 16, .minute = 44, .second = 41, .nanosecond = 161131219 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1565853318838868781);

    // 2081-03-28T11:05:41.079667+00:00 :
    dt_from_unix = try Datetime.fromUnix(3510385541079667552, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2081, .month = 3, .day = 28, .hour = 11, .minute = 5, .second = 41, .nanosecond = 79667552 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3510385541079667552);

    // 2052-06-16T01:27:20.929793+00:00 :
    dt_from_unix = try Datetime.fromUnix(2602114040929793135, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2052, .month = 6, .day = 16, .hour = 1, .minute = 27, .second = 20, .nanosecond = 929793135 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2602114040929793135);

    // 1969-11-16T12:53:36.178644+00:00 :
    dt_from_unix = try Datetime.fromUnix(-3927983821355260, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1969, .month = 11, .day = 16, .hour = 12, .minute = 53, .second = 36, .nanosecond = 178644740 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -3927983821355260);

    // 2031-12-10T14:02:32.602351+00:00 :
    dt_from_unix = try Datetime.fromUnix(1954677752602351957, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2031, .month = 12, .day = 10, .hour = 14, .minute = 2, .second = 32, .nanosecond = 602351957 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1954677752602351957);

    // 1977-01-19T01:06:50.327543+00:00 :
    dt_from_unix = try Datetime.fromUnix(222484010327543903, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1977, .month = 1, .day = 19, .hour = 1, .minute = 6, .second = 50, .nanosecond = 327543903 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 222484010327543903);

    // 2096-06-01T21:34:11.019304+00:00 :
    dt_from_unix = try Datetime.fromUnix(3989424851019304584, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2096, .month = 6, .day = 1, .hour = 21, .minute = 34, .second = 11, .nanosecond = 19304584 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3989424851019304584);

    // 1962-09-07T21:18:19.730489+00:00 :
    dt_from_unix = try Datetime.fromUnix(-230870500269510410, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1962, .month = 9, .day = 7, .hour = 21, .minute = 18, .second = 19, .nanosecond = 730489590 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -230870500269510410);

    // 1992-07-23T11:55:49.386543+00:00 :
    dt_from_unix = try Datetime.fromUnix(711892549386543484, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1992, .month = 7, .day = 23, .hour = 11, .minute = 55, .second = 49, .nanosecond = 386543484 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 711892549386543484);

    // 1915-12-20T13:12:26.388025+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1705142853611974752, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1915, .month = 12, .day = 20, .hour = 13, .minute = 12, .second = 26, .nanosecond = 388025248 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1705142853611974752);

    // 2014-07-03T09:57:05.887228+00:00 :
    dt_from_unix = try Datetime.fromUnix(1404381425887228803, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2014, .month = 7, .day = 3, .hour = 9, .minute = 57, .second = 5, .nanosecond = 887228803 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1404381425887228803);

    // 1918-11-23T03:31:15.394206+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1612816124605793516, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1918, .month = 11, .day = 23, .hour = 3, .minute = 31, .second = 15, .nanosecond = 394206484 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1612816124605793516);

    // 2061-11-20T12:33:59.601124+00:00 :
    dt_from_unix = try Datetime.fromUnix(2899715639601124826, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2061, .month = 11, .day = 20, .hour = 12, .minute = 33, .second = 59, .nanosecond = 601124826 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2899715639601124826);

    // 1960-09-09T07:43:38.490583+00:00 :
    dt_from_unix = try Datetime.fromUnix(-293818581509416584, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1960, .month = 9, .day = 9, .hour = 7, .minute = 43, .second = 38, .nanosecond = 490583416 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -293818581509416584);

    // 2042-06-29T20:17:40.209685+00:00 :
    dt_from_unix = try Datetime.fromUnix(2287685860209685194, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2042, .month = 6, .day = 29, .hour = 20, .minute = 17, .second = 40, .nanosecond = 209685194 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2287685860209685194);

    // 2083-06-27T08:14:07.792741+00:00 :
    dt_from_unix = try Datetime.fromUnix(3581309647792741096, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2083, .month = 6, .day = 27, .hour = 8, .minute = 14, .second = 7, .nanosecond = 792741096 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3581309647792741096);

    // 1940-10-12T08:42:36.883113+00:00 :
    dt_from_unix = try Datetime.fromUnix(-922115843116886901, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1940, .month = 10, .day = 12, .hour = 8, .minute = 42, .second = 36, .nanosecond = 883113099 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -922115843116886901);

    // 1939-11-09T11:20:31.070174+00:00 :
    dt_from_unix = try Datetime.fromUnix(-951309568929825326, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1939, .month = 11, .day = 9, .hour = 11, .minute = 20, .second = 31, .nanosecond = 70174674 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -951309568929825326);

    // 2053-11-02T09:22:40.170619+00:00 :
    dt_from_unix = try Datetime.fromUnix(2645688160170619441, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2053, .month = 11, .day = 2, .hour = 9, .minute = 22, .second = 40, .nanosecond = 170619441 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2645688160170619441);

    // 2022-04-15T05:01:16.560761+00:00 :
    dt_from_unix = try Datetime.fromUnix(1649998876560761362, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2022, .month = 4, .day = 15, .hour = 5, .minute = 1, .second = 16, .nanosecond = 560761362 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1649998876560761362);

    // 2066-07-22T08:02:29.370997+00:00 :
    dt_from_unix = try Datetime.fromUnix(3047011349370997433, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2066, .month = 7, .day = 22, .hour = 8, .minute = 2, .second = 29, .nanosecond = 370997433 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3047011349370997433);

    // 2003-04-29T02:49:42.810775+00:00 :
    dt_from_unix = try Datetime.fromUnix(1051584582810775420, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2003, .month = 4, .day = 29, .hour = 2, .minute = 49, .second = 42, .nanosecond = 810775420 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1051584582810775420);

    // 1939-06-27T02:21:26.895600+00:00 :
    dt_from_unix = try Datetime.fromUnix(-963005913104399522, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1939, .month = 6, .day = 27, .hour = 2, .minute = 21, .second = 26, .nanosecond = 895600478 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -963005913104399522);

    // 2040-11-11T00:15:55.510952+00:00 :
    dt_from_unix = try Datetime.fromUnix(2236205755510952884, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2040, .month = 11, .day = 11, .hour = 0, .minute = 15, .second = 55, .nanosecond = 510952884 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2236205755510952884);

    // 1943-08-17T16:30:33.293621+00:00 :
    dt_from_unix = try Datetime.fromUnix(-832318166706378254, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1943, .month = 8, .day = 17, .hour = 16, .minute = 30, .second = 33, .nanosecond = 293621746 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -832318166706378254);

    // 1945-08-31T02:59:52.472004+00:00 :
    dt_from_unix = try Datetime.fromUnix(-767998807527995945, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1945, .month = 8, .day = 31, .hour = 2, .minute = 59, .second = 52, .nanosecond = 472004055 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -767998807527995945);

    // 2094-03-24T04:09:30.992268+00:00 :
    dt_from_unix = try Datetime.fromUnix(3920242170992268689, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2094, .month = 3, .day = 24, .hour = 4, .minute = 9, .second = 30, .nanosecond = 992268689 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3920242170992268689);

    // 2070-03-25T15:18:28.308200+00:00 :
    dt_from_unix = try Datetime.fromUnix(3162986308308200669, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2070, .month = 3, .day = 25, .hour = 15, .minute = 18, .second = 28, .nanosecond = 308200669 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3162986308308200669);

    // 2009-10-27T23:10:08.501264+00:00 :
    dt_from_unix = try Datetime.fromUnix(1256685008501264661, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2009, .month = 10, .day = 27, .hour = 23, .minute = 10, .second = 8, .nanosecond = 501264661 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1256685008501264661);

    // 2070-01-30T08:27:09.900066+00:00 :
    dt_from_unix = try Datetime.fromUnix(3158296029900066100, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2070, .month = 1, .day = 30, .hour = 8, .minute = 27, .second = 9, .nanosecond = 900066100 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3158296029900066100);

    // 2033-08-05T05:00:22.010777+00:00 :
    dt_from_unix = try Datetime.fromUnix(2006830822010777062, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2033, .month = 8, .day = 5, .hour = 5, .minute = 0, .second = 22, .nanosecond = 10777062 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2006830822010777062);

    // 1971-10-05T21:57:44.246697+00:00 :
    dt_from_unix = try Datetime.fromUnix(55547864246697412, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1971, .month = 10, .day = 5, .hour = 21, .minute = 57, .second = 44, .nanosecond = 246697412 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 55547864246697412);

    // 2057-11-26T19:17:17.634489+00:00 :
    dt_from_unix = try Datetime.fromUnix(2774027837634489745, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2057, .month = 11, .day = 26, .hour = 19, .minute = 17, .second = 17, .nanosecond = 634489745 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2774027837634489745);

    // 2094-03-03T12:06:46.920080+00:00 :
    dt_from_unix = try Datetime.fromUnix(3918456406920080347, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2094, .month = 3, .day = 3, .hour = 12, .minute = 6, .second = 46, .nanosecond = 920080347 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3918456406920080347);

    // 1932-09-12T00:47:58.929337+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1177197121070662181, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1932, .month = 9, .day = 12, .hour = 0, .minute = 47, .second = 58, .nanosecond = 929337819 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1177197121070662181);

    // 1997-02-04T06:55:26.909075+00:00 :
    dt_from_unix = try Datetime.fromUnix(855039326909075882, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1997, .month = 2, .day = 4, .hour = 6, .minute = 55, .second = 26, .nanosecond = 909075882 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 855039326909075882);

    // 1983-10-10T08:56:19.343081+00:00 :
    dt_from_unix = try Datetime.fromUnix(434624179343081111, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1983, .month = 10, .day = 10, .hour = 8, .minute = 56, .second = 19, .nanosecond = 343081111 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 434624179343081111);

    // 1945-02-21T22:10:20.039834+00:00 :
    dt_from_unix = try Datetime.fromUnix(-784432179960165746, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1945, .month = 2, .day = 21, .hour = 22, .minute = 10, .second = 20, .nanosecond = 39834254 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -784432179960165746);

    // 1900-12-05T07:13:21.177763+00:00 :
    dt_from_unix = try Datetime.fromUnix(-2179759598822236804, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1900, .month = 12, .day = 5, .hour = 7, .minute = 13, .second = 21, .nanosecond = 177763196 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -2179759598822236804);

    // 2044-11-26T18:53:42.845748+00:00 :
    dt_from_unix = try Datetime.fromUnix(2363799222845748194, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2044, .month = 11, .day = 26, .hour = 18, .minute = 53, .second = 42, .nanosecond = 845748194 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2363799222845748194);

    // 1930-05-17T08:08:46.514799+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1250524273485200451, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1930, .month = 5, .day = 17, .hour = 8, .minute = 8, .second = 46, .nanosecond = 514799549 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1250524273485200451);

    // 2078-06-23T13:20:07.491094+00:00 :
    dt_from_unix = try Datetime.fromUnix(3423216007491094459, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2078, .month = 6, .day = 23, .hour = 13, .minute = 20, .second = 7, .nanosecond = 491094459 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3423216007491094459);

    // 2044-11-24T20:54:56.084391+00:00 :
    dt_from_unix = try Datetime.fromUnix(2363633696084391143, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2044, .month = 11, .day = 24, .hour = 20, .minute = 54, .second = 56, .nanosecond = 84391143 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2363633696084391143);

    // 1956-10-10T11:17:23.164359+00:00 :
    dt_from_unix = try Datetime.fromUnix(-417357756835640568, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1956, .month = 10, .day = 10, .hour = 11, .minute = 17, .second = 23, .nanosecond = 164359432 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -417357756835640568);

    // 2006-09-22T12:20:41.467261+00:00 :
    dt_from_unix = try Datetime.fromUnix(1158927641467261187, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2006, .month = 9, .day = 22, .hour = 12, .minute = 20, .second = 41, .nanosecond = 467261187 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1158927641467261187);

    // 1946-02-10T11:30:35.105377+00:00 :
    dt_from_unix = try Datetime.fromUnix(-753884964894622715, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1946, .month = 2, .day = 10, .hour = 11, .minute = 30, .second = 35, .nanosecond = 105377285 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -753884964894622715);

    // 2070-12-14T22:13:58.714065+00:00 :
    dt_from_unix = try Datetime.fromUnix(3185820838714065473, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2070, .month = 12, .day = 14, .hour = 22, .minute = 13, .second = 58, .nanosecond = 714065473 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3185820838714065473);

    // 2039-06-18T03:14:41.104955+00:00 :
    dt_from_unix = try Datetime.fromUnix(2191979681104955255, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2039, .month = 6, .day = 18, .hour = 3, .minute = 14, .second = 41, .nanosecond = 104955255 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2191979681104955255);

    // 1931-12-07T04:18:16.195458+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1201376503804541105, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1931, .month = 12, .day = 7, .hour = 4, .minute = 18, .second = 16, .nanosecond = 195458895 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1201376503804541105);

    // 2003-08-09T17:54:30.345777+00:00 :
    dt_from_unix = try Datetime.fromUnix(1060451670345777945, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2003, .month = 8, .day = 9, .hour = 17, .minute = 54, .second = 30, .nanosecond = 345777945 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 1060451670345777945);

    // 1968-05-06T20:56:02.893567+00:00 :
    dt_from_unix = try Datetime.fromUnix(-52196637106432923, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1968, .month = 5, .day = 6, .hour = 20, .minute = 56, .second = 2, .nanosecond = 893567077 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -52196637106432923);

    // 1968-10-01T20:20:08.557338+00:00 :
    dt_from_unix = try Datetime.fromUnix(-39411591442661547, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1968, .month = 10, .day = 1, .hour = 20, .minute = 20, .second = 8, .nanosecond = 557338453 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -39411591442661547);

    // 2061-12-08T23:06:33.724088+00:00 :
    dt_from_unix = try Datetime.fromUnix(2901308793724088827, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2061, .month = 12, .day = 8, .hour = 23, .minute = 6, .second = 33, .nanosecond = 724088827 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2901308793724088827);

    // 1922-06-25T10:39:00.560758+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1499606459439241118, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1922, .month = 6, .day = 25, .hour = 10, .minute = 39, .second = 0, .nanosecond = 560758882 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1499606459439241118);

    // 2052-01-18T14:40:05.997253+00:00 :
    dt_from_unix = try Datetime.fromUnix(2589201605997253876, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2052, .month = 1, .day = 18, .hour = 14, .minute = 40, .second = 5, .nanosecond = 997253876 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2589201605997253876);

    // 1935-11-24T12:36:13.946292+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1076239426053707437, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1935, .month = 11, .day = 24, .hour = 12, .minute = 36, .second = 13, .nanosecond = 946292563 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -1076239426053707437);

    // 2088-04-22T23:40:17.280861+00:00 :
    dt_from_unix = try Datetime.fromUnix(3733515617280861100, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2088, .month = 4, .day = 22, .hour = 23, .minute = 40, .second = 17, .nanosecond = 280861100 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3733515617280861100);

    // 1947-02-18T11:52:36.124080+00:00 :
    dt_from_unix = try Datetime.fromUnix(-721656443875919949, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1947, .month = 2, .day = 18, .hour = 11, .minute = 52, .second = 36, .nanosecond = 124080051 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == -721656443875919949);

    // 2050-08-11T23:51:27.770691+00:00 :
    dt_from_unix = try Datetime.fromUnix(2543874687770691667, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2050, .month = 8, .day = 11, .hour = 23, .minute = 51, .second = 27, .nanosecond = 770691667 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 2543874687770691667);

    // 2073-02-19T10:07:28.691610+00:00 :
    dt_from_unix = try Datetime.fromUnix(3254724448691610553, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2073, .month = 2, .day = 19, .hour = 10, .minute = 7, .second = 28, .nanosecond = 691610553 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 3254724448691610553);

    // 2096-11-26T17:12:15.289130+00:00 :
    dt_from_unix = try Datetime.fromUnix(4004788335289130856, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2096, .month = 11, .day = 26, .hour = 17, .minute = 12, .second = 15, .nanosecond = 289130856 });
    try testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try testing.expect(unix == 4004788335289130856);
}
