//! test duration from a users's perspective (no internal functionality)

const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;

const log = std.log.scoped(.test_duration);

const TestCaseISODur = struct {
    string: []const u8 = "",
    fields: Duration.RelativeDeltaFields = .{},
    duration: Duration = .{},
};

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

test "iso duration parser, full valid input" {
    const cases = [_]TestCaseISODur{
        .{
            .string = "P1Y2M3DT4H5M6.789S",
            .fields = .{ .years = 1, .months = 2, .days = 3, .hours = 4, .minutes = 5, .seconds = 6, .nanoseconds = 789000000 },
        },
        .{
            .string = "P-2Y3M4DT5H6M7.89S",
            .fields = .{ .years = -2, .months = 3, .days = 4, .hours = 5, .minutes = 6, .seconds = 7, .nanoseconds = 890000000 },
        },
        .{
            .string = "P999Y0M0DT0H0M0.123S",
            .fields = .{ .years = 999, .months = 0, .days = 0, .hours = 0, .minutes = 0, .seconds = 0, .nanoseconds = 123000000 },
        },
        .{
            .string = "P3Y4M5DT6H7M8.9S",
            .fields = .{ .years = 3, .months = 4, .days = 5, .hours = 6, .minutes = 7, .seconds = 8, .nanoseconds = 900000000 },
        },
        .{
            .string = "P-5Y6M7DT8H9M10.111000001S",
            .fields = .{ .years = -5, .months = 6, .days = 7, .hours = 8, .minutes = 9, .seconds = 10, .nanoseconds = 111000001 },
        },
        .{
            .string = "P7Y8M9DT10H11M12.123S",
            .fields = .{ .years = 7, .months = 8, .days = 9, .hours = 10, .minutes = 11, .seconds = 12, .nanoseconds = 123000000 },
        },
        .{
            .string = "P-8Y9M10DT11H12M13.145S",
            .fields = .{ .years = -8, .months = 9, .days = 10, .hours = 11, .minutes = 12, .seconds = 13, .nanoseconds = 145000000 },
        },
        .{
            .string = "-P9Y10M11DT12H13M14.156S",
            .fields = .{ .years = -9, .months = -10, .days = -11, .hours = -12, .minutes = -13, .seconds = -14, .nanoseconds = 156000000 },
        },
    };

    for (cases) |case| {
        const fields = try Duration.parseIsoDur(case.string);
        try testing.expectEqual(case.fields, fields);

        // all test cases have year or month != 0, so conversion to duration fails:
        const err = Duration.fromISO8601Duration(case.string);
        try testing.expectError(error.InvalidFormat, err);
    }
}

test "iso duration to Duration type round-trip" {
    const cases = [_]TestCaseISODur{
        .{
            .string = "PT4H5M6.789S",
            .duration = .{ .__sec = 4 * 3600 + 5 * 60 + 6, .__nsec = 789000000 },
        },
        .{
            .string = "PT37H0M12.789000001S", // default formatter prints components that are zero
            .duration = .{ .__sec = 37 * 3600 + 12, .__nsec = 789000001 },
        },
        .{
            .string = "-PT0H46M59.789S",
            .duration = .{ .__sec = -(46 * 60 + 59), .__nsec = 789000000 },
        },
    };

    for (cases) |case| {
        const dur = try Duration.fromISO8601Duration(case.string);
        try testing.expectEqual(case.duration, dur);

        var buf = std.ArrayList(u8).init(testing.allocator);
        defer buf.deinit();
        try dur.format("{s}", .{}, buf.writer());
        try testing.expectEqualStrings(case.string, buf.items);
        buf.clearAndFree();
    }
}

test "iso duration fail cases" {
    const cases = [_][]const u8{
        "-PT;0H46M59.789S",
        "yPT0H46M59.789S",
        "-P--T0H46M59.789S",
        "P1Y2M3DT4K5M6.789S",
        "PX2Y3M4DT5H6M7.89S",
        "P999Y0M0D 0H0M0.123S",
        "P+999Y0M0DT0H0M0.123S",
        "P3Y4M5DT6H7M8.9>",
        "P-+5Y6M7DT8H9M10.111000001S",
        "P7Y8M9DT10H11M12;123S",
        "P-8Y9M10XT11H12M13.145S",
        "-P9Y10M11DT12H13M14.156s",
    };

    for (cases) |case| {
        const err = Duration.parseIsoDur(case) catch error.InvalidFormat;
        try testing.expectError(error.InvalidFormat, err);
    }
}
