//! test datetime from a users's perspective (no internal functionality)

const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const UTCoffset = zdt.UTCoffset;
const ZdtError = zdt.ZdtError;

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

test "Datetime from empty field struct" {
    const dt = try Datetime.fromFields(.{});
    try testing.expectEqual(@as(u16, 1), dt.year);
    try testing.expectEqual(@as(u8, 1), dt.month);
    try testing.expectEqual(@as(u5, 1), dt.day);
    try testing.expect(dt.tz == null);
}

test "Datetime from populated field struct" {
    const dt = try Datetime.fromFields(.{ .year = 2023, .month = 12 });
    try testing.expectEqual(@as(u16, 2023), dt.year);
    try testing.expectEqual(@as(u8, 12), dt.month);
    try testing.expectEqual(@as(u5, 1), dt.day);
    try testing.expect(dt.tz == null);
    try testing.expectEqual(false, dt.isAware());
    try testing.expectEqual(true, dt.isNaive());
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
    const dt_from_fields = try Datetime.fromFields(.{ .year = 1990, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 60 });
    try testing.expectEqual(@as(u8, 60), dt_from_fields.second);

    const unix_s = dt_from_fields.toUnix(Duration.Resolution.second);
    try testing.expectEqual(@as(i128, 662687999), unix_s);
    const normal_dt = try Datetime.fromFields(.{ .year = 1985, .month = 6, .day = 30, .hour = 23, .minute = 59, .second = 59 });
    _ = try normal_dt.validateLeap();
    const leap_dt = try Datetime.fromFields(.{ .year = 1985, .month = 6, .day = 30, .hour = 23, .minute = 59, .second = 60 });
    _ = try leap_dt.validateLeap();

    const dt_from_int = try Datetime.fromUnix(60, Duration.Resolution.second, null);
    try testing.expectEqual(@as(u8, 0), dt_from_int.second);
    try testing.expectEqual(@as(u8, 1), dt_from_int.minute);
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
    try testing.expect(dt.unix_sec == Datetime.unix_s_min);

    fields = Datetime.Fields{ .year = Datetime.max_year, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 59, .nanosecond = 999999999 };
    dt = try Datetime.fromFields(fields);
    try testing.expect(dt.year == Datetime.max_year);
    try testing.expect(dt.hour == 23);
    try testing.expectEqual(Datetime.unix_s_max, dt.unix_sec);
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
    const too_large_ns = Datetime.fromUnix(@as(i128, Datetime.unix_s_max + 1) * std.time.ns_per_s, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_large_ns);
    const too_small_s = Datetime.fromUnix(Datetime.unix_s_min - 1, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_small_s);
    const too_small_ns = Datetime.fromUnix(@as(i128, Datetime.unix_s_min - 1) * std.time.ns_per_s, Duration.Resolution.second, null);
    try testing.expectError(ZdtError.UnixOutOfRange, too_small_ns);
}

test "Epoch" {
    var epoch = Datetime.epoch;
    try testing.expectEqual(epoch.year, 1970);
    try testing.expectEqual(epoch.month, 1);
    try testing.expectEqual(epoch.day, 1);
    try testing.expectEqual(epoch.unix_sec, 0);
    try testing.expectEqual(true, epoch.isAware());
    try testing.expectEqual(false, epoch.isNaive());
    try testing.expectEqualStrings(epoch.tzAbbreviation(), "Z");
    try testing.expectEqualStrings(epoch.tzName(), "UTC");
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
    var offset = try UTCoffset.fromSeconds(3600, "", false);
    var dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .utc_offset = offset } });

    var str = std.ArrayList(u8).init(testing.allocator);
    try dt.formatOffset(.{ .fill = ':' }, str.writer());
    try testing.expectEqualStrings("+01:00", str.items);

    str.clearAndFree();
    try dt.format("", .{}, str.writer());
    try testing.expectEqualStrings("2021-02-18T17:00:00+01:00", str.items);

    offset = try UTCoffset.fromSeconds(3600 * 9 + 942, "", false);
    dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .utc_offset = offset } });
    str.clearAndFree();
    try dt.formatOffset(.{ .fill = ':', .precision = 2 }, str.writer());
    try testing.expectEqualStrings("+09:15:42", str.items);
    str.deinit();
}

test "compare Unix time" {
    const offset = try UTCoffset.fromSeconds(3600, "", false);
    var a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .utc_offset = offset } });
    const b = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18 });

    var err = Datetime.compareUT(a, b);
    try testing.expectError(ZdtError.CompareNaiveAware, err);
    err = Datetime.compareUT(b, a);
    try testing.expectError(ZdtError.CompareNaiveAware, err);

    var want_eq = try Datetime.compareUT(a, a);
    try testing.expectEqual(std.math.Order.eq, want_eq);
    want_eq = try Datetime.compareUT(b, b);
    try testing.expectEqual(std.math.Order.eq, want_eq);

    a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 });
    const want_lt = try Datetime.compareUT(a, b);
    try testing.expectEqual(std.math.Order.lt, want_lt);
    const want_gt = try Datetime.compareUT(b, a);
    try testing.expectEqual(std.math.Order.gt, want_gt);
}

test "compare wall time" {
    const offset = try UTCoffset.fromSeconds(3600, "", false);
    var a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42 });
    const b = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42, .tz_options = .{ .utc_offset = offset } });
    try testing.expectEqual(std.math.Order.eq, try Datetime.compareWall(a, b));

    a = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 42 });
    try testing.expectEqual(std.math.Order.lt, try Datetime.compareWall(a, b));
    try testing.expectEqual(std.math.Order.gt, try Datetime.compareWall(b, a));
}

test "floor naive datetime to the second" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42 });
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
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42 });
    const dt_floored = try dt.floorTo(Duration.Timespan.minute);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(dt_floored.hour, dt.hour);
    try testing.expectEqual(dt_floored.minute, dt.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(u32, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(u32, 0), dt_floored.nanosecond);
}

test "floor naive datetime to the hour" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .minute = 5, .second = 32, .nanosecond = 42 });
    const dt_floored = try dt.floorTo(Duration.Timespan.hour);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(dt_floored.hour, dt.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(u32, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(u32, 0), dt_floored.nanosecond);
}

test "floor naive datetime to the date" {
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 18, .nanosecond = 42 });
    const dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(dt_floored.year, dt.year);
    try testing.expectEqual(dt_floored.month, dt.month);
    try testing.expectEqual(dt_floored.day, dt.day);
    try testing.expectEqual(@as(u8, 0), dt_floored.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(u32, 0), dt_floored.nanosecond);
    try testing.expectEqual(@as(i64, 1613606400), dt_floored.unix_sec);
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
    var i: u8 = 1;
    while (i < 8) : (i += 1) {
        try testing.expectEqual(i, @as(u8, dt.weekdayIsoNumber()));
        dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.day));
    }
}

test "weekday enum" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqual(Datetime.Weekday.Thursday, dt.weekday());
    try testing.expectEqualStrings("Thu", dt.weekday().shortName());
    try testing.expectEqualStrings("Thursday", dt.weekday().longName());

    var d = try Datetime.Weekday.nameToInt("Saturday");
    try testing.expectEqual(6, d);

    d = try Datetime.Weekday.nameShortToInt("Thu");
    try testing.expectEqual(4, d);
}

test "month enum" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqualStrings("Jan", dt.monthEnum().shortName());
    try testing.expectEqualStrings("January", dt.monthEnum().longName());

    var m = try Datetime.Month.nameToInt("June");
    try testing.expectEqual(6, m);

    m = try Datetime.Month.nameShortToInt("Apr");
    try testing.expectEqual(4, m);
}

test "next weekday" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    const nextThu = dt.nextWeekday(Datetime.Weekday.Thursday);
    try testing.expectEqualStrings("Thursday", nextThu.weekday().longName());
    try testing.expectEqual(@as(u8, 8), nextThu.day);

    const nextWed = dt.nextWeekday(Datetime.Weekday.Wednesday);
    try testing.expectEqualStrings("Wednesday", nextWed.weekday().longName());
    try testing.expectEqual(@as(u8, 7), nextWed.day);

    const nextSun = dt.nextWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqualStrings("Sunday", nextSun.weekday().longName());
    try testing.expectEqual(@as(u8, 4), nextSun.day);
}

test "prev weekday" {
    const dt = try Datetime.fromFields(.{ .year = 1970 });
    const prevThu = dt.previousWeekday(Datetime.Weekday.Thursday);
    try testing.expectEqualStrings("Thursday", prevThu.weekday().longName());
    try testing.expectEqual(@as(u8, 25), prevThu.day);

    const prevWed = dt.previousWeekday(Datetime.Weekday.Wednesday);
    try testing.expectEqualStrings("Wednesday", prevWed.weekday().longName());
    try testing.expectEqual(@as(u8, 31), prevWed.day);

    const prevSun = dt.previousWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqualStrings("Sunday", prevSun.weekday().longName());
    try testing.expectEqual(@as(u8, 28), prevSun.day);
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
    try testing.expectEqual(@as(u8, 0), dt.weekOfYearSun());
    const nextSun = dt.nextWeekday(Datetime.Weekday.Sunday);
    try testing.expectEqual(@as(u8, 1), nextSun.weekOfYearSun());

    try testing.expectEqual(@as(u8, 0), nextSun.weekOfYearMon());
    const nextMon = dt.nextWeekday(Datetime.Weekday.Monday);
    try testing.expectEqual(@as(u8, 1), nextMon.weekOfYearMon());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 31 });
    try testing.expectEqual(@as(u8, 53), dt.weekOfYearSun());
    try testing.expectEqual(@as(u8, 52), dt.weekOfYearMon());
}

test "iso calendar" {
    var dt = try Datetime.fromFields(.{ .year = 2024, .month = 1, .day = 9 });
    var isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 2), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1977, .month = 1, .day = 1 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 53), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1977, .month = 12, .day = 31 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 1, .day = 1 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 1, .day = 2 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1978, .month = 12, .day = 31 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 28 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 29 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 30 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 52), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1979, .month = 12, .day = 31 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1980, .month = 1, .day = 1 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 1), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1981, .month = 12, .day = 31 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 53), isocal.isoweek);
    dt = try Datetime.fromFields(.{ .year = 1982, .month = 1, .day = 3 });
    isocal = dt.toISOCalendar();
    try testing.expectEqual(@as(u8, 53), isocal.isoweek);
}

test "isocalendar to datetime and vice versa" {
    var ical = Datetime.ISOCalendar{ .isoyear = 2004, .isoweek = 53, .isoweekday = 6 };
    var ref_dt = try Datetime.fromFields(.{ .year = 2005, .month = 1, .day = 1 });
    var ical_dt = try ical.toDatetime();
    var dt_ical = ical_dt.toISOCalendar();
    try testing.expectEqual(ref_dt, ical_dt);
    try testing.expectEqual(ical, dt_ical);

    ical = Datetime.ISOCalendar{ .isoyear = 2010, .isoweek = 1, .isoweekday = 1 };
    ref_dt = try Datetime.fromFields(.{ .year = 2010, .month = 1, .day = 4 });
    ical_dt = try ical.toDatetime();
    dt_ical = ical_dt.toISOCalendar();
    try testing.expectEqual(ref_dt, ical_dt);
    try testing.expectEqual(ical, dt_ical);

    ical = Datetime.ISOCalendar{ .isoyear = 2009, .isoweek = 53, .isoweekday = 7 };
    ref_dt = try Datetime.fromFields(.{ .year = 2010, .month = 1, .day = 3 });
    ical_dt = try ical.toDatetime();
    dt_ical = ical_dt.toISOCalendar();
    try testing.expectEqual(ref_dt, ical_dt);
    try testing.expectEqual(ical, dt_ical);

    ical = Datetime.ISOCalendar{ .isoyear = 2024, .isoweek = 40, .isoweekday = 4 };
    ref_dt = try Datetime.fromFields(.{ .year = 2024, .month = 10, .day = 3 });
    ical_dt = try ical.toDatetime();
    dt_ical = ical_dt.toISOCalendar();
    try testing.expectEqual(ref_dt, ical_dt);
    try testing.expectEqual(ical, dt_ical);
}

test "isocal from string" {
    const ical = Datetime.ISOCalendar{ .isoyear = 2024, .isoweek = 40, .isoweekday = 4 };
    const fromstr = try Datetime.ISOCalendar.fromString("2024-W40-4");
    try testing.expectEqual(ical, fromstr);

    const err = Datetime.ISOCalendar.fromString("2024-40-4");
    try testing.expectError(error.InvalidFormat, err);
}

test "replace fields" {
    const dt = try Datetime.fromISO8601("2020-02-03T04:05:06.777888999");
    var new_dt = try dt.replace(.{ .year = 2022 });
    try testing.expectEqual(2022, new_dt.year); // must change
    try testing.expectEqual(2, new_dt.month); // must NOT change

    new_dt = try dt.replace(.{ .month = 3 });
    try testing.expectEqual(3, new_dt.month);

    new_dt = try dt.replace(.{ .nanosecond = 1 });
    try testing.expectEqual(1, new_dt.nanosecond);

    var err = dt.replace(.{ .second = 60 }); // not a leap second!
    try testing.expectError(error.SecondOutOfRange, err);

    err = dt.replace(.{ .month = 13 }); // ensure is checked
    try testing.expectError(error.MonthOutOfRange, err);
}

// the following test is auto-generated by gen_test_dt-from-unix.py. do not edit this line and below.

test "unix nanoseconds, fields" {
    var dt_from_unix: Datetime = .{};
    var dt_from_fields: Datetime = .{};
    var unix: i128 = 0;

    // 2006-02-13T07:49:30.157447+00:00 :
    dt_from_unix = try Datetime.fromUnix(1139816970157447204, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2006, .month = 2, .day = 13, .hour = 7, .minute = 49, .second = 30, .nanosecond = 157447204 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1139816970157447204, unix);

    // 1911-07-04T16:58:55.335801+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1845961264664198296, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1911, .month = 7, .day = 4, .hour = 16, .minute = 58, .second = 55, .nanosecond = 335801704 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1845961264664198296, unix);

    // 1976-04-03T16:17:57.112616+00:00 :
    dt_from_unix = try Datetime.fromUnix(197396277112616585, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1976, .month = 4, .day = 3, .hour = 16, .minute = 17, .second = 57, .nanosecond = 112616585 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(197396277112616585, unix);

    // 1993-06-15T03:31:07.631347+00:00 :
    dt_from_unix = try Datetime.fromUnix(740115067631347709, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1993, .month = 6, .day = 15, .hour = 3, .minute = 31, .second = 7, .nanosecond = 631347709 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(740115067631347709, unix);

    // 1965-09-10T21:10:04.900889+00:00 :
    dt_from_unix = try Datetime.fromUnix(-135917395099110276, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1965, .month = 9, .day = 10, .hour = 21, .minute = 10, .second = 4, .nanosecond = 900889724 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-135917395099110276, unix);

    // 2025-05-11T07:55:43.346194+00:00 :
    dt_from_unix = try Datetime.fromUnix(1746950143346194291, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2025, .month = 5, .day = 11, .hour = 7, .minute = 55, .second = 43, .nanosecond = 346194291 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1746950143346194291, unix);

    // 2033-09-19T08:52:23.419743+00:00 :
    dt_from_unix = try Datetime.fromUnix(2010732743419743984, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2033, .month = 9, .day = 19, .hour = 8, .minute = 52, .second = 23, .nanosecond = 419743984 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2010732743419743984, unix);

    // 2011-11-25T20:30:45.142200+00:00 :
    dt_from_unix = try Datetime.fromUnix(1322253045142200462, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2011, .month = 11, .day = 25, .hour = 20, .minute = 30, .second = 45, .nanosecond = 142200462 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1322253045142200462, unix);

    // 1974-07-17T16:08:44.216813+00:00 :
    dt_from_unix = try Datetime.fromUnix(143309324216813127, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1974, .month = 7, .day = 17, .hour = 16, .minute = 8, .second = 44, .nanosecond = 216813127 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(143309324216813127, unix);

    // 1970-06-15T23:04:13.701167+00:00 :
    dt_from_unix = try Datetime.fromUnix(14339053701167226, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1970, .month = 6, .day = 15, .hour = 23, .minute = 4, .second = 13, .nanosecond = 701167226 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(14339053701167226, unix);

    // 1959-03-24T23:34:55.696166+00:00 :
    dt_from_unix = try Datetime.fromUnix(-339985504303833582, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1959, .month = 3, .day = 24, .hour = 23, .minute = 34, .second = 55, .nanosecond = 696166418 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-339985504303833582, unix);

    // 2005-03-22T04:41:50.599516+00:00 :
    dt_from_unix = try Datetime.fromUnix(1111466510599516821, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2005, .month = 3, .day = 22, .hour = 4, .minute = 41, .second = 50, .nanosecond = 599516821 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1111466510599516821, unix);

    // 2057-10-16T13:20:17.421883+00:00 :
    dt_from_unix = try Datetime.fromUnix(2770464017421883411, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2057, .month = 10, .day = 16, .hour = 13, .minute = 20, .second = 17, .nanosecond = 421883411 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2770464017421883411, unix);

    // 1924-12-02T17:41:26.878193+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1422598713121806117, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1924, .month = 12, .day = 2, .hour = 17, .minute = 41, .second = 26, .nanosecond = 878193883 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1422598713121806117, unix);

    // 1968-04-22T02:14:14.542383+00:00 :
    dt_from_unix = try Datetime.fromUnix(-53473545457616547, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1968, .month = 4, .day = 22, .hour = 2, .minute = 14, .second = 14, .nanosecond = 542383453 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-53473545457616547, unix);

    // 2071-12-05T04:41:36.510627+00:00 :
    dt_from_unix = try Datetime.fromUnix(3216516096510627205, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2071, .month = 12, .day = 5, .hour = 4, .minute = 41, .second = 36, .nanosecond = 510627205 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3216516096510627205, unix);

    // 2050-04-16T18:20:18.629659+00:00 :
    dt_from_unix = try Datetime.fromUnix(2533746018629659335, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2050, .month = 4, .day = 16, .hour = 18, .minute = 20, .second = 18, .nanosecond = 629659335 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2533746018629659335, unix);

    // 2040-11-07T18:01:31.246681+00:00 :
    dt_from_unix = try Datetime.fromUnix(2235924091246681545, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2040, .month = 11, .day = 7, .hour = 18, .minute = 1, .second = 31, .nanosecond = 246681545 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2235924091246681545, unix);

    // 2095-10-06T02:49:51.563857+00:00 :
    dt_from_unix = try Datetime.fromUnix(3968707791563857370, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2095, .month = 10, .day = 6, .hour = 2, .minute = 49, .second = 51, .nanosecond = 563857370 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3968707791563857370, unix);

    // 1906-02-17T08:23:28.253135+00:00 :
    dt_from_unix = try Datetime.fromUnix(-2015595391746864347, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1906, .month = 2, .day = 17, .hour = 8, .minute = 23, .second = 28, .nanosecond = 253135653 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-2015595391746864347, unix);

    // 2030-04-26T08:44:23.368914+00:00 :
    dt_from_unix = try Datetime.fromUnix(1903423463368914145, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2030, .month = 4, .day = 26, .hour = 8, .minute = 44, .second = 23, .nanosecond = 368914145 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1903423463368914145, unix);

    // 2093-01-17T14:57:50.411423+00:00 :
    dt_from_unix = try Datetime.fromUnix(3883042670411423755, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2093, .month = 1, .day = 17, .hour = 14, .minute = 57, .second = 50, .nanosecond = 411423755 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3883042670411423755, unix);

    // 2087-08-25T06:40:03.604387+00:00 :
    dt_from_unix = try Datetime.fromUnix(3712632003604387205, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2087, .month = 8, .day = 25, .hour = 6, .minute = 40, .second = 3, .nanosecond = 604387205 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3712632003604387205, unix);

    // 1996-03-05T04:01:33.200875+00:00 :
    dt_from_unix = try Datetime.fromUnix(825998493200875839, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1996, .month = 3, .day = 5, .hour = 4, .minute = 1, .second = 33, .nanosecond = 200875839 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(825998493200875839, unix);

    // 2014-07-30T05:41:43.718062+00:00 :
    dt_from_unix = try Datetime.fromUnix(1406698903718062404, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2014, .month = 7, .day = 30, .hour = 5, .minute = 41, .second = 43, .nanosecond = 718062404 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1406698903718062404, unix);

    // 2079-01-02T08:34:17.727757+00:00 :
    dt_from_unix = try Datetime.fromUnix(3439874057727757792, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2079, .month = 1, .day = 2, .hour = 8, .minute = 34, .second = 17, .nanosecond = 727757792 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3439874057727757792, unix);

    // 2089-04-15T16:45:14.981203+00:00 :
    dt_from_unix = try Datetime.fromUnix(3764421914981203364, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2089, .month = 4, .day = 15, .hour = 16, .minute = 45, .second = 14, .nanosecond = 981203364 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3764421914981203364, unix);

    // 2001-07-15T23:49:30.572376+00:00 :
    dt_from_unix = try Datetime.fromUnix(995240970572376801, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2001, .month = 7, .day = 15, .hour = 23, .minute = 49, .second = 30, .nanosecond = 572376801 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(995240970572376801, unix);

    // 2085-12-16T15:41:54.673785+00:00 :
    dt_from_unix = try Datetime.fromUnix(3659355714673785261, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2085, .month = 12, .day = 16, .hour = 15, .minute = 41, .second = 54, .nanosecond = 673785261 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3659355714673785261, unix);

    // 2068-01-31T16:03:15.928089+00:00 :
    dt_from_unix = try Datetime.fromUnix(3095251395928089236, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2068, .month = 1, .day = 31, .hour = 16, .minute = 3, .second = 15, .nanosecond = 928089236 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3095251395928089236, unix);

    // 2053-07-16T04:39:03.670448+00:00 :
    dt_from_unix = try Datetime.fromUnix(2636253543670448791, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2053, .month = 7, .day = 16, .hour = 4, .minute = 39, .second = 3, .nanosecond = 670448791 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2636253543670448791, unix);

    // 2049-01-26T19:12:56.022732+00:00 :
    dt_from_unix = try Datetime.fromUnix(2495301176022732233, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2049, .month = 1, .day = 26, .hour = 19, .minute = 12, .second = 56, .nanosecond = 22732233 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2495301176022732233, unix);

    // 2057-07-27T21:06:01.959375+00:00 :
    dt_from_unix = try Datetime.fromUnix(2763493561959375132, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2057, .month = 7, .day = 27, .hour = 21, .minute = 6, .second = 1, .nanosecond = 959375132 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2763493561959375132, unix);

    // 2014-02-23T21:56:38.419373+00:00 :
    dt_from_unix = try Datetime.fromUnix(1393192598419373852, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2014, .month = 2, .day = 23, .hour = 21, .minute = 56, .second = 38, .nanosecond = 419373852 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1393192598419373852, unix);

    // 1970-05-05T22:45:53.859058+00:00 :
    dt_from_unix = try Datetime.fromUnix(10795553859058913, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1970, .month = 5, .day = 5, .hour = 22, .minute = 45, .second = 53, .nanosecond = 859058913 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(10795553859058913, unix);

    // 1976-01-28T07:20:41.147095+00:00 :
    dt_from_unix = try Datetime.fromUnix(191661641147095672, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1976, .month = 1, .day = 28, .hour = 7, .minute = 20, .second = 41, .nanosecond = 147095672 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(191661641147095672, unix);

    // 1971-05-08T08:19:43.172751+00:00 :
    dt_from_unix = try Datetime.fromUnix(42538783172751947, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1971, .month = 5, .day = 8, .hour = 8, .minute = 19, .second = 43, .nanosecond = 172751947 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(42538783172751947, unix);

    // 2057-04-14T06:25:36.565828+00:00 :
    dt_from_unix = try Datetime.fromUnix(2754455136565828242, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2057, .month = 4, .day = 14, .hour = 6, .minute = 25, .second = 36, .nanosecond = 565828242 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2754455136565828242, unix);

    // 1951-06-13T01:15:34.804713+00:00 :
    dt_from_unix = try Datetime.fromUnix(-585528265195286599, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1951, .month = 6, .day = 13, .hour = 1, .minute = 15, .second = 34, .nanosecond = 804713401 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-585528265195286599, unix);

    // 1921-09-22T21:06:50.877267+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1523415189122732770, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1921, .month = 9, .day = 22, .hour = 21, .minute = 6, .second = 50, .nanosecond = 877267230 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1523415189122732770, unix);

    // 1975-06-19T10:02:26.769740+00:00 :
    dt_from_unix = try Datetime.fromUnix(172404146769740667, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1975, .month = 6, .day = 19, .hour = 10, .minute = 2, .second = 26, .nanosecond = 769740667 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(172404146769740667, unix);

    // 2062-03-30T22:59:52.749455+00:00 :
    dt_from_unix = try Datetime.fromUnix(2910985192749455412, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2062, .month = 3, .day = 30, .hour = 22, .minute = 59, .second = 52, .nanosecond = 749455412 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2910985192749455412, unix);

    // 1929-11-13T00:23:14.749022+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1266536205250977058, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1929, .month = 11, .day = 13, .hour = 0, .minute = 23, .second = 14, .nanosecond = 749022942 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1266536205250977058, unix);

    // 2034-05-16T00:49:01.138436+00:00 :
    dt_from_unix = try Datetime.fromUnix(2031353341138436500, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2034, .month = 5, .day = 16, .hour = 0, .minute = 49, .second = 1, .nanosecond = 138436500 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2031353341138436500, unix);

    // 2016-08-15T19:58:24.806277+00:00 :
    dt_from_unix = try Datetime.fromUnix(1471291104806277326, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2016, .month = 8, .day = 15, .hour = 19, .minute = 58, .second = 24, .nanosecond = 806277326 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1471291104806277326, unix);

    // 2027-09-19T10:04:59.644137+00:00 :
    dt_from_unix = try Datetime.fromUnix(1821348299644137670, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2027, .month = 9, .day = 19, .hour = 10, .minute = 4, .second = 59, .nanosecond = 644137670 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1821348299644137670, unix);

    // 1903-08-16T20:57:39.201585+00:00 :
    dt_from_unix = try Datetime.fromUnix(-2094692540798414766, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1903, .month = 8, .day = 16, .hour = 20, .minute = 57, .second = 39, .nanosecond = 201585234 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-2094692540798414766, unix);

    // 1980-10-20T09:43:08.732900+00:00 :
    dt_from_unix = try Datetime.fromUnix(340882988732900487, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1980, .month = 10, .day = 20, .hour = 9, .minute = 43, .second = 8, .nanosecond = 732900487 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(340882988732900487, unix);

    // 2077-12-18T13:15:08.880882+00:00 :
    dt_from_unix = try Datetime.fromUnix(3407058908880882376, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2077, .month = 12, .day = 18, .hour = 13, .minute = 15, .second = 8, .nanosecond = 880882376 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3407058908880882376, unix);

    // 2020-03-29T06:39:33.998392+00:00 :
    dt_from_unix = try Datetime.fromUnix(1585463973998392555, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2020, .month = 3, .day = 29, .hour = 6, .minute = 39, .second = 33, .nanosecond = 998392555 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1585463973998392555, unix);

    // 1977-12-18T19:07:32.591266+00:00 :
    dt_from_unix = try Datetime.fromUnix(251320052591266848, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1977, .month = 12, .day = 18, .hour = 19, .minute = 7, .second = 32, .nanosecond = 591266848 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(251320052591266848, unix);

    // 1905-08-26T12:42:48.251099+00:00 :
    dt_from_unix = try Datetime.fromUnix(-2030699831748900962, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1905, .month = 8, .day = 26, .hour = 12, .minute = 42, .second = 48, .nanosecond = 251099038 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-2030699831748900962, unix);

    // 1911-10-29T00:43:19.724354+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1835911000275645366, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1911, .month = 10, .day = 29, .hour = 0, .minute = 43, .second = 19, .nanosecond = 724354634 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1835911000275645366, unix);

    // 2021-01-29T11:08:32.946010+00:00 :
    dt_from_unix = try Datetime.fromUnix(1611918512946010890, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2021, .month = 1, .day = 29, .hour = 11, .minute = 8, .second = 32, .nanosecond = 946010890 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1611918512946010890, unix);

    // 1995-01-26T00:52:22.256639+00:00 :
    dt_from_unix = try Datetime.fromUnix(791081542256639804, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1995, .month = 1, .day = 26, .hour = 0, .minute = 52, .second = 22, .nanosecond = 256639804 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(791081542256639804, unix);

    // 2081-12-14T10:58:42.784782+00:00 :
    dt_from_unix = try Datetime.fromUnix(3532935522784782786, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2081, .month = 12, .day = 14, .hour = 10, .minute = 58, .second = 42, .nanosecond = 784782786 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3532935522784782786, unix);

    // 2058-06-16T04:11:26.495154+00:00 :
    dt_from_unix = try Datetime.fromUnix(2791426286495154255, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2058, .month = 6, .day = 16, .hour = 4, .minute = 11, .second = 26, .nanosecond = 495154255 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2791426286495154255, unix);

    // 2041-08-25T01:38:07.571380+00:00 :
    dt_from_unix = try Datetime.fromUnix(2261007487571380607, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2041, .month = 8, .day = 25, .hour = 1, .minute = 38, .second = 7, .nanosecond = 571380607 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2261007487571380607, unix);

    // 1932-07-27T20:53:06.297782+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1181185613702217311, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1932, .month = 7, .day = 27, .hour = 20, .minute = 53, .second = 6, .nanosecond = 297782689 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1181185613702217311, unix);

    // 2031-06-08T17:03:58.474063+00:00 :
    dt_from_unix = try Datetime.fromUnix(1938704638474063316, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2031, .month = 6, .day = 8, .hour = 17, .minute = 3, .second = 58, .nanosecond = 474063316 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1938704638474063316, unix);

    // 1986-08-31T16:31:49.994491+00:00 :
    dt_from_unix = try Datetime.fromUnix(525889909994491835, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1986, .month = 8, .day = 31, .hour = 16, .minute = 31, .second = 49, .nanosecond = 994491835 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(525889909994491835, unix);

    // 2086-10-28T21:01:36.630063+00:00 :
    dt_from_unix = try Datetime.fromUnix(3686677296630063857, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2086, .month = 10, .day = 28, .hour = 21, .minute = 1, .second = 36, .nanosecond = 630063857 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3686677296630063857, unix);

    // 2046-11-07T03:20:51.843511+00:00 :
    dt_from_unix = try Datetime.fromUnix(2425173651843511531, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2046, .month = 11, .day = 7, .hour = 3, .minute = 20, .second = 51, .nanosecond = 843511531 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2425173651843511531, unix);

    // 2035-09-12T05:07:54.992775+00:00 :
    dt_from_unix = try Datetime.fromUnix(2073186474992775101, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2035, .month = 9, .day = 12, .hour = 5, .minute = 7, .second = 54, .nanosecond = 992775101 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2073186474992775101, unix);

    // 2020-10-27T07:14:33.322766+00:00 :
    dt_from_unix = try Datetime.fromUnix(1603782873322766604, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2020, .month = 10, .day = 27, .hour = 7, .minute = 14, .second = 33, .nanosecond = 322766604 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1603782873322766604, unix);

    // 2022-04-25T22:00:05.144375+00:00 :
    dt_from_unix = try Datetime.fromUnix(1650924005144375799, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2022, .month = 4, .day = 25, .hour = 22, .minute = 0, .second = 5, .nanosecond = 144375799 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1650924005144375799, unix);

    // 1919-03-24T22:16:36.922882+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1602294203077117410, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1919, .month = 3, .day = 24, .hour = 22, .minute = 16, .second = 36, .nanosecond = 922882590 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1602294203077117410, unix);

    // 1934-08-30T22:17:10.073246+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1115170969926753570, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1934, .month = 8, .day = 30, .hour = 22, .minute = 17, .second = 10, .nanosecond = 73246430 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1115170969926753570, unix);

    // 1911-04-06T14:31:43.402977+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1853659696597022699, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1911, .month = 4, .day = 6, .hour = 14, .minute = 31, .second = 43, .nanosecond = 402977301 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1853659696597022699, unix);

    // 1918-04-05T04:26:09.604044+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1632857630395955914, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1918, .month = 4, .day = 5, .hour = 4, .minute = 26, .second = 9, .nanosecond = 604044086 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1632857630395955914, unix);

    // 1927-12-28T07:55:17.978510+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1325779482021489161, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1927, .month = 12, .day = 28, .hour = 7, .minute = 55, .second = 17, .nanosecond = 978510839 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1325779482021489161, unix);

    // 2078-01-15T20:58:43.722981+00:00 :
    dt_from_unix = try Datetime.fromUnix(3409505923722981966, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2078, .month = 1, .day = 15, .hour = 20, .minute = 58, .second = 43, .nanosecond = 722981966 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3409505923722981966, unix);

    // 2093-08-14T20:32:19.511857+00:00 :
    dt_from_unix = try Datetime.fromUnix(3901120339511857368, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2093, .month = 8, .day = 14, .hour = 20, .minute = 32, .second = 19, .nanosecond = 511857368 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3901120339511857368, unix);

    // 1920-02-27T11:16:24.349769+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1572957815650230821, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1920, .month = 2, .day = 27, .hour = 11, .minute = 16, .second = 24, .nanosecond = 349769179 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1572957815650230821, unix);

    // 2032-05-15T22:32:49.528714+00:00 :
    dt_from_unix = try Datetime.fromUnix(1968273169528714623, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2032, .month = 5, .day = 15, .hour = 22, .minute = 32, .second = 49, .nanosecond = 528714623 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1968273169528714623, unix);

    // 2020-06-27T17:00:26.715258+00:00 :
    dt_from_unix = try Datetime.fromUnix(1593277226715258764, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2020, .month = 6, .day = 27, .hour = 17, .minute = 0, .second = 26, .nanosecond = 715258764 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1593277226715258764, unix);

    // 2091-12-21T08:27:54.060431+00:00 :
    dt_from_unix = try Datetime.fromUnix(3849064074060431958, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2091, .month = 12, .day = 21, .hour = 8, .minute = 27, .second = 54, .nanosecond = 60431958 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3849064074060431958, unix);

    // 2087-12-04T04:15:22.007149+00:00 :
    dt_from_unix = try Datetime.fromUnix(3721349722007149573, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2087, .month = 12, .day = 4, .hour = 4, .minute = 15, .second = 22, .nanosecond = 7149573 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3721349722007149573, unix);

    // 1947-12-22T15:17:09.971666+00:00 :
    dt_from_unix = try Datetime.fromUnix(-695119370028333617, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1947, .month = 12, .day = 22, .hour = 15, .minute = 17, .second = 9, .nanosecond = 971666383 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-695119370028333617, unix);

    // 1978-03-21T18:31:40.719801+00:00 :
    dt_from_unix = try Datetime.fromUnix(259353100719801983, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1978, .month = 3, .day = 21, .hour = 18, .minute = 31, .second = 40, .nanosecond = 719801983 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(259353100719801983, unix);

    // 1996-05-12T21:52:06.935207+00:00 :
    dt_from_unix = try Datetime.fromUnix(831937926935207836, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1996, .month = 5, .day = 12, .hour = 21, .minute = 52, .second = 6, .nanosecond = 935207836 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(831937926935207836, unix);

    // 2039-09-16T17:57:48.298809+00:00 :
    dt_from_unix = try Datetime.fromUnix(2199808668298809902, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2039, .month = 9, .day = 16, .hour = 17, .minute = 57, .second = 48, .nanosecond = 298809902 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2199808668298809902, unix);

    // 1985-12-28T03:09:57.313186+00:00 :
    dt_from_unix = try Datetime.fromUnix(504587397313186504, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1985, .month = 12, .day = 28, .hour = 3, .minute = 9, .second = 57, .nanosecond = 313186504 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(504587397313186504, unix);

    // 2081-10-21T11:19:41.534193+00:00 :
    dt_from_unix = try Datetime.fromUnix(3528271181534193650, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2081, .month = 10, .day = 21, .hour = 11, .minute = 19, .second = 41, .nanosecond = 534193650 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3528271181534193650, unix);

    // 1976-06-24T08:50:13.067365+00:00 :
    dt_from_unix = try Datetime.fromUnix(204454213067365555, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1976, .month = 6, .day = 24, .hour = 8, .minute = 50, .second = 13, .nanosecond = 67365555 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(204454213067365555, unix);

    // 2006-04-17T00:29:16.830281+00:00 :
    dt_from_unix = try Datetime.fromUnix(1145233756830281912, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2006, .month = 4, .day = 17, .hour = 0, .minute = 29, .second = 16, .nanosecond = 830281912 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(1145233756830281912, unix);

    // 1933-11-18T09:46:52.175769+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1139839987824230190, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1933, .month = 11, .day = 18, .hour = 9, .minute = 46, .second = 52, .nanosecond = 175769810 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1139839987824230190, unix);

    // 1912-10-13T12:31:05.308802+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1805628534691197833, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1912, .month = 10, .day = 13, .hour = 12, .minute = 31, .second = 5, .nanosecond = 308802167 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1805628534691197833, unix);

    // 2081-10-11T19:25:53.550118+00:00 :
    dt_from_unix = try Datetime.fromUnix(3527436353550118265, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2081, .month = 10, .day = 11, .hour = 19, .minute = 25, .second = 53, .nanosecond = 550118265 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3527436353550118265, unix);

    // 2060-09-11T07:26:53.914799+00:00 :
    dt_from_unix = try Datetime.fromUnix(2862113213914799238, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2060, .month = 9, .day = 11, .hour = 7, .minute = 26, .second = 53, .nanosecond = 914799238 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2862113213914799238, unix);

    // 1996-11-18T20:02:47.772468+00:00 :
    dt_from_unix = try Datetime.fromUnix(848347367772468167, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1996, .month = 11, .day = 18, .hour = 20, .minute = 2, .second = 47, .nanosecond = 772468167 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(848347367772468167, unix);

    // 1905-10-09T15:32:55.099978+00:00 :
    dt_from_unix = try Datetime.fromUnix(-2026888024900021709, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1905, .month = 10, .day = 9, .hour = 15, .minute = 32, .second = 55, .nanosecond = 99978291 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-2026888024900021709, unix);

    // 2077-04-21T06:21:57.695324+00:00 :
    dt_from_unix = try Datetime.fromUnix(3386211717695324281, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2077, .month = 4, .day = 21, .hour = 6, .minute = 21, .second = 57, .nanosecond = 695324281 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(3386211717695324281, unix);

    // 2047-09-08T08:51:54.574312+00:00 :
    dt_from_unix = try Datetime.fromUnix(2451545514574312538, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2047, .month = 9, .day = 8, .hour = 8, .minute = 51, .second = 54, .nanosecond = 574312538 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2451545514574312538, unix);

    // 1915-08-02T22:31:41.958495+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1717205298041504919, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1915, .month = 8, .day = 2, .hour = 22, .minute = 31, .second = 41, .nanosecond = 958495081 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1717205298041504919, unix);

    // 2058-10-18T05:59:11.003833+00:00 :
    dt_from_unix = try Datetime.fromUnix(2802146351003833012, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 2058, .month = 10, .day = 18, .hour = 5, .minute = 59, .second = 11, .nanosecond = 3833012 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(2802146351003833012, unix);

    // 1955-09-03T09:52:42.309110+00:00 :
    dt_from_unix = try Datetime.fromUnix(-452182037690889720, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1955, .month = 9, .day = 3, .hour = 9, .minute = 52, .second = 42, .nanosecond = 309110280 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-452182037690889720, unix);

    // 1985-10-16T10:01:15.428375+00:00 :
    dt_from_unix = try Datetime.fromUnix(498304875428375353, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1985, .month = 10, .day = 16, .hour = 10, .minute = 1, .second = 15, .nanosecond = 428375353 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(498304875428375353, unix);

    // 1989-02-08T18:38:38.127399+00:00 :
    dt_from_unix = try Datetime.fromUnix(602966318127399728, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1989, .month = 2, .day = 8, .hour = 18, .minute = 38, .second = 38, .nanosecond = 127399728 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(602966318127399728, unix);

    // 1925-09-11T08:02:20.348743+00:00 :
    dt_from_unix = try Datetime.fromUnix(-1398182259651256224, Duration.Resolution.nanosecond, null);
    dt_from_fields = try Datetime.fromFields(.{ .year = 1925, .month = 9, .day = 11, .hour = 8, .minute = 2, .second = 20, .nanosecond = 348743776 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
    unix = dt_from_fields.toUnix(Duration.Resolution.nanosecond);
    try std.testing.expectEqual(-1398182259651256224, unix);
}
