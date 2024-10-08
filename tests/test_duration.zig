//! test duration from a users's perspective (no internal functionality)

const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;

const log = std.log.scoped(.test_duration);

test "from timespan" {
    var td = Duration.fromTimespanMultiple(5, Duration.Timespan.nanosecond);
    try testing.expectEqual(@as(i128, 5), td.asNanoseconds());

    td = Duration.fromTimespanMultiple(32, Duration.Timespan.second);
    try testing.expectEqual(@as(i128, 32E9), td.asNanoseconds());
    try testing.expectEqual(@as(i64, 32), td.asSeconds());

    td = Duration.fromTimespanMultiple(1, Duration.Timespan.week);
    try testing.expectEqual(@as(i64, 7 * 24 * 60 * 60), td.asSeconds());
}

test "to timespan" {
    var td = Duration.fromTimespanMultiple(5, Duration.Timespan.nanosecond);
    try testing.expectEqual(@as(i128, 5), td.asNanoseconds());

    const ns = td.toTimespanMultiple(Duration.Timespan.nanosecond);
    try testing.expectEqual(@as(i128, 5), ns);

    const weeks = td.toTimespanMultiple(Duration.Timespan.week);
    try testing.expectEqual(@as(i128, 1), weeks);

    td = Duration.fromTimespanMultiple(5500, Duration.Timespan.microsecond);
    var ms = td.toTimespanMultiple(Duration.Timespan.millisecond);
    try testing.expectEqual(@as(i128, 6), ms);

    td = Duration.fromTimespanMultiple(5501, Duration.Timespan.microsecond);
    ms = td.toTimespanMultiple(Duration.Timespan.millisecond);
    try testing.expectEqual(@as(i128, 6), ms);
}

test "total seconds" {
    const td = Duration.fromTimespanMultiple(3141592653, Duration.Timespan.nanosecond);
    try testing.expectEqual(3.141592653, td.totalSeconds());
}

test "add durations" {
    var a = Duration{ .__sec = 1 };
    var b = Duration{ .__sec = 1 };
    var c = a.add(b);
    try testing.expectEqual(@as(i64, 2), c.__sec);
    try testing.expectEqual(@as(u32, 0), c.__nsec);

    a = Duration{ .__sec = 1 };
    b = Duration{ .__nsec = 1 };
    c = a.add(b);
    try testing.expectEqual(@as(i64, 1), c.__sec);
    try testing.expectEqual(@as(u32, 1), c.__nsec);

    a = Duration{ .__nsec = 500_000_000 };
    b = Duration{ .__nsec = 500_000_314 };
    c = a.add(b);
    try testing.expectEqual(@as(i64, 1), c.__sec);
    try testing.expectEqual(@as(u32, 314), c.__nsec);
}

test "sub durations" {
    var a = Duration{ .__sec = 1 };
    var b = Duration{ .__sec = 1 };
    var c = a.sub(b);
    try testing.expectEqual(@as(i64, 0), c.__sec);
    try testing.expectEqual(@as(u32, 0), c.__nsec);

    a = Duration{ .__sec = 1 };
    b = Duration{ .__nsec = 1 };
    c = a.sub(b);
    try testing.expectEqual(@as(i64, 0), c.__sec);
    try testing.expectEqual(@as(u32, 999_999_999), c.__nsec);

    a = Duration{ .__nsec = 500_000_000 };
    b = Duration{ .__nsec = 500_000_314 };
    c = a.sub(b);
    try testing.expectEqual(@as(i64, -1), c.__sec);
    try testing.expectEqual(@as(u32, 999999686), c.__nsec);
}

test "add duration to datetime" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .second = 42 });
    dt = try dt.add(Duration{ .__sec = 1, .__nsec = 0 });
    try testing.expectEqual(@as(i64, 43), dt.unix_sec);

    dt = try dt.add(Duration{ .__sec = -1, .__nsec = 0 });
    try testing.expectEqual(@as(i64, 42), dt.unix_sec);

    dt = try dt.add(Duration{ .__sec = -1, .__nsec = 1E9 });
    try testing.expectEqual(@as(i64, 42), dt.unix_sec);
    try testing.expectEqual(@as(u32, 0), dt.nanosecond);

    dt = try dt.add(Duration.fromTimespanMultiple(1, Duration.Timespan.week));
    try testing.expectEqual(@as(u6, 8), dt.day);
}

test "subtract duration from datetime" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .second = 42 });
    dt = try dt.sub(Duration{ .__sec = -1, .__nsec = 0 });
    try testing.expectEqual(@as(i64, 43), dt.unix_sec);

    dt = try dt.sub(Duration{ .__sec = 1, .__nsec = 0 });
    try testing.expectEqual(@as(i64, 42), dt.unix_sec);

    dt = try dt.sub(Duration{ .__sec = 1, .__nsec = 1E9 });
    try testing.expectEqual(@as(i64, 42), dt.unix_sec);
    try testing.expectEqual(@as(u32, 0), dt.nanosecond);
}

test "datetime difference" {
    var a = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    var b = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    var diff = a.diff(b);
    try testing.expectEqual(@as(i64, 0), diff.__sec);
    try testing.expectEqual(@as(u32, 0), diff.__nsec);

    a = try Datetime.fromFields(.{ .year = 1970, .second = 0 });
    b = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    diff = a.diff(b);
    try testing.expectEqual(@as(i64, -1), diff.__sec);
    try testing.expectEqual(@as(u32, 0), diff.__nsec);

    diff = b.diff(a);
    try testing.expectEqual(@as(i64, 1), diff.__sec);
    try testing.expectEqual(@as(u32, 0), diff.__nsec);
}

test "leap second difference" {
    var a = try Datetime.fromISO8601("1972-06-30");
    var b = try Datetime.fromISO8601("1972-07-01");
    var leaps = a.diffLeap(b);
    try testing.expectEqual(@as(i64, -1), leaps.__sec);
    try testing.expectEqual(@as(u32, 0), leaps.__nsec);
    var diff = a.diff(b).add(leaps);
    try testing.expectEqual(@as(i64, -86401), diff.__sec);
    try testing.expectEqual(@as(u32, 0), diff.__nsec);

    a = try Datetime.fromISO8601("1973-01-01");
    b = try Datetime.fromISO8601("1972-06-30");
    leaps = a.diffLeap(b);
    try testing.expectEqual(@as(i64, 2), leaps.__sec);
    try testing.expectEqual(@as(u32, 0), leaps.__nsec);

    a = try Datetime.fromISO8601("1970-01-01");
    b = try Datetime.fromISO8601("2024-01-01");
    leaps = a.diffLeap(b);
    try testing.expectEqual(@as(i64, -27), leaps.__sec);
    try testing.expectEqual(@as(u32, 0), leaps.__nsec);

    a = try Datetime.fromISO8601("2024-01-01");
    b = try Datetime.fromISO8601("2016-12-31"); // before last leap second insertion
    leaps = a.diffLeap(b);
    try testing.expectEqual(@as(i64, 1), leaps.__sec);
    try testing.expectEqual(@as(u32, 0), leaps.__nsec);

    a = try Datetime.fromISO8601("2024-10-01");
    b = try Datetime.fromISO8601("2024-10-02");
    leaps = a.diffLeap(b);
    try testing.expectEqual(@as(i64, 0), leaps.__sec);
    try testing.expectEqual(@as(u32, 0), leaps.__nsec);
    diff = a.diff(b).add(leaps);
    try testing.expectEqual(@as(i64, -86400), diff.__sec);
    try testing.expectEqual(@as(u32, 0), diff.__nsec);
}
