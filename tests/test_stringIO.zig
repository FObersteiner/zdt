//! test stringIO from a user's perspective (no internal functionality)
const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const log = std.log.scoped(.zdt_test_stringIO);

const c_locale = @cImport(@cInclude("locale.h"));
const time_mask = switch (builtin.os.tag) {
    .linux => c_locale.LC_TIME_MASK,
    else => c_locale.LC_TIME,
};

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const td = zdt.Duration;
const Tz = zdt.Timezone;
const str = zdt.stringIO;

const TestCase = struct {
    string: []const u8,
    dt: Datetime,
    directive: []const u8 = "",
};

// locale-specific tests only for English
fn locale_ok() bool {
    const loc = c_locale.setlocale(time_mask, "");
    const env_locale: [:0]const u8 = std.mem.span(loc);
    // log.warn("got locale: {s}\n", .{env_locale});
    if (!(std.mem.eql(u8, env_locale, "en_US.UTF-8") or
        std.mem.eql(u8, env_locale, "English_United States.utf8") or
        std.mem.eql(u8, env_locale, "en_GB.UTF-8") or
        std.mem.eql(u8, env_locale, "C.UTF-8") or
        std.mem.eql(u8, env_locale, "English_United States.1252") or
        std.mem.eql(u8, env_locale, "C")))
    {
        log.warn("can only run test with English locale; got {s}\n", .{env_locale});
        return false;
    }
    return true;
}

// ---- Datetime to String ----

test "format naive datetimes with format string api" {
    const cases = [_]TestCase{
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
            .string = "2021-02-18 17:00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
            .string = "1970-01-01 00:00:00",
        },
    };

    for (cases) |case| {
        var s = std.ArrayList(u8).init(testing.allocator);
        defer s.deinit();
        try str.formatToString(s.writer(), "%Y-%m-%d %H:%M:%S", case.dt);
        try testing.expectEqualStrings(case.string, s.items);
    }
}

test "format datetime with literal characters in format string" {
    const cases = [_]TestCase{ .{
        .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
        .string = "2021-02-18T17:00:00",
        .directive = "%Y-%m-%dT%H:%M:%S",
    }, .{
        .dt = try Datetime.fromFields(.{ .year = 1970 }),
        .string = "Unix epoch 1970-01-01 00:00:00",
        .directive = "Unix epoch %Y-%m-%d %H:%M:%S",
    }, .{
        .dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 9, .hour = 1, .minute = 2, .second = 3 }),
        .string = "% 2023-12-09 % 01:02:03 %",
        .directive = "%% %Y-%m-%d %% %H:%M:%S %%",
    }, .{
        .dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 10, .hour = 1, .minute = 2, .second = 3, .nanosecond = 456789 }),
        .string = "2023-12-10 01:02:03.000456789",
        .directive = "%Y-%m-%d %H:%M:%S.%f",
    } };

    for (cases) |case| {
        var s = std.ArrayList(u8).init(testing.allocator);
        defer s.deinit();
        try str.formatToString(s.writer(), case.directive, case.dt);
        try testing.expectEqualStrings(case.string, s.items);
    }
}

test "format with z" {
    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const tzinfo = try Tz.fromOffset(3600, "");
    const dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const string = "2021-02-18T17:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with z, full day off" {
    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const tzinfo = try Tz.fromOffset(-86400, "");
    const dt = try Datetime.fromFields(.{ .year = 1970, .month = 2, .day = 13, .hour = 12, .tzinfo = tzinfo });
    const string = "1970-02-13T12:00:00-24:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with z, strange directive" {
    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const tzinfo = try Tz.fromOffset(900, "");
    const dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 9, .hour = 1, .minute = 2, .second = 3, .tzinfo = tzinfo });
    const string = "% 2023-12-09 % 01:02:03 % +00:15";
    const directive = "%% %Y-%m-%d %% %H:%M:%S %% %z";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with Z" {
    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const tz_utc = Tz.UTC;
    const dt = try Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 9, .hour = 1, .minute = 2, .second = 3, .tzinfo = tz_utc });
    const string = "2023-12-09T01:02:03+00:00Z";
    const directive = "%Y-%m-%dT%H:%M:%S%z%Z";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);

    var tz_pacific = try Tz.fromTzfile("America/Los_Angeles", testing.allocator);
    defer tz_pacific.deinit();
    const dt_std = try dt.tzConvert(tz_pacific);
    var s_std = std.ArrayList(u8).init(testing.allocator);
    defer s_std.deinit();
    const directive_us = "%Y-%m-%dT%H:%M:%S%z %Z";
    const string_std = "2023-12-08T17:02:03-08:00 PST";
    try str.formatToString(s_std.writer(), directive_us, dt_std);
    try testing.expectEqualStrings(string_std, s_std.items);

    const dt_dst = try dt_std.add(td.fromTimespanMultiple(6 * 4, td.Timespan.week));
    var s_dst = std.ArrayList(u8).init(testing.allocator);
    defer s_dst.deinit();
    const string_dst = "2024-05-24T18:02:03-07:00 PDT";
    try str.formatToString(s_dst.writer(), directive_us, dt_dst);
    try testing.expectEqualStrings(string_dst, s_dst.items);
}

test "format with abbreviated day name" {
    if (!locale_ok()) return error.SkipZigTest;

    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const dt = Datetime.epoch;
    const string = "Thu";
    const directive = "%a";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with day name" {
    if (!locale_ok()) return error.SkipZigTest;

    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const dt = Datetime.epoch;
    const string = "Thursday";
    const directive = "%A";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with abbreviated month name" {
    if (!locale_ok()) return error.SkipZigTest;

    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const dt = Datetime.epoch;
    const string = "Jan";
    const directive = "%b";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "format with month name" {
    if (!locale_ok()) return error.SkipZigTest;

    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const dt = Datetime.epoch;
    const string = "January";
    const directive = "%B";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

// ---- String to Datetime ----

test "comptime parse with comptime format string" {
    const cases = [_]TestCase{
        .{
            .string = "2021-02-18 17:00:01",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .second = 1 }),
        },
        .{
            .string = "1970-01-01 00:00:00",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };

    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%d %H:%M:%S", case.string);
        try testing.expectEqual(case.dt, dt);
    }
}

test "comptime parse with fractional part" {
    const cases = [_]TestCase{
        .{
            .string = "2021-02-18T17:00:00.1",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 100_000_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.12",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 120_000_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.123",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_000_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.1234",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_400_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.12345",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_450_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.123456",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_456_000 }),
        },
        .{
            .string = "2021-02-18T17:00:00.1234567",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_456_700 }),
        },
        .{
            .string = "2021-02-18T17:00:00.12345678",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_456_780 }),
        },
        .{
            .string = "2021-02-18T17:00:00.123456789",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .nanosecond = 123_456_789 }),
        },
    };

    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%dT%H:%M:%S.%f", case.string);
        try testing.expectEqual(case.dt, dt);
    }
}

test "parse single digits" {
    const cases = [_]TestCase{
        .{ // single digit y m d
            .string = "1-1-1 00:00:00",
            .dt = try Datetime.fromFields(.{}),
        },
        .{ // single digit field at end of string
            .string = "1-1-1 0:0:0",
            .dt = try Datetime.fromFields(.{}),
        },
    };

    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%d %H:%M:%S", case.string);
        try testing.expectEqual(case.dt, dt);
    }
}

test "parsing directives do not match fields in string" {
    var err = str.parseToDatetime("%Y-%m-%d %H%%%M%%%S", "1970-01-01 00:00:00");
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseToDatetime("%Y-%m-%dT%H:%M:%S", "1970-01-01 00:00:00");
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseToDatetime("%", "1970-01-01 00:00:00");
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseToDatetime("%Y-%m-%d %H:%M:%S %z", "1970-01-01 00:00:00 +7");
    try testing.expectError(error.InvalidFormat, err);
}

test "parse with literal characters" {
    var cases = [_]TestCase{
        .{
            .string = "datetime 2021-02-18 17:00:00",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
        },
        .{
            .string = "datetime 1970-01-01 00:00:00",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };
    for (cases) |case| {
        const dt = try str.parseToDatetime("datetime %Y-%m-%d %H:%M:%S", case.string);
        try testing.expectEqual(case.dt, dt);
        try testing.expect(dt.tzinfo == null);
    }

    cases = [_]TestCase{
        .{
            .string = "2021-02-18 17:00:00 datetime",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
        },
        .{
            .string = "1970-01-01 00:00:00 datetime",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };
    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%d %H:%M:%S datetime", case.string);
        try testing.expectEqual(case.dt, dt);
        try testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{
            .string = "2021-02-18 %% 17:00:00",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
        },
        .{
            .string = "1970-01-01 %% 00:00:00",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };
    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%d %%%% %H:%M:%S", case.string);
        try testing.expectEqual(case.dt, dt);
        try testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{
            .string = "%2021-02-18 17:00:00",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17 }),
        },
        .{
            .string = "%1970-01-01 00:00:00",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };
    for (cases) |case| {
        const dt = try str.parseToDatetime("%%%Y-%m-%d %H:%M:%S", case.string);
        try testing.expectEqual(case.dt, dt);
        try testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{
            .string = "2021-02-18 12%34%56",
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 12, .minute = 34, .second = 56 }),
        },
        .{
            .string = "1970-01-01 00%00%00",
            .dt = try Datetime.fromFields(.{ .year = 1970 }),
        },
    };
    for (cases) |case| {
        const dt = try str.parseToDatetime("%Y-%m-%d %H%%%M%%%S", case.string);
        try testing.expectEqual(case.dt, dt);
        try testing.expect(dt.tzinfo == null);
    }
}

test "parse with z" {
    var tzinfo = try Tz.fromOffset(3600, "");
    var dt_ref = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const s_hhmm = "2021-02-18T17:00:00+01:00";
    var dt = try str.parseToDatetime("%Y-%m-%dT%H:%M:%S%z", s_hhmm);
    try testing.expectEqual(dt_ref.year, dt.year);

    var off_want = dt_ref.tzinfo.?.tzOffset.?.seconds_east;
    var off_have = dt.tzinfo.?.tzOffset.?.seconds_east;
    try testing.expectEqual(@as(i20, 3600), off_have);
    try testing.expectEqual(off_want, off_have);

    // with seconds in UTC offset
    tzinfo = try Tz.fromOffset(-3601, "");
    dt_ref = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const s_hhmmss = "2021-02-18T17:00:00-01:00:01";
    dt = try str.parseToDatetime("%Y-%m-%dT%H:%M:%S%z", s_hhmmss);
    try testing.expectEqual(dt_ref.year, dt.year);

    off_want = dt_ref.tzinfo.?.tzOffset.?.seconds_east;
    off_have = dt.tzinfo.?.tzOffset.?.seconds_east;
    try testing.expectEqual(@as(i20, -3601), off_have);
    try testing.expectEqual(off_want, off_have);

    // literal Z
    // Note : a literal Z = UTC always implies an offset of 0;
    // however, an offset of 0 does not unambiguously mean UTC.
    tzinfo = try Tz.fromOffset(0, "");
    dt_ref = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const Z = "2021-02-18T17:00:00Z";
    dt = try str.parseToDatetime("%Y-%m-%dT%H:%M:%S%z", Z);
    try testing.expectEqual(dt_ref.year, dt.year);
    off_want = dt_ref.tzinfo.?.tzOffset.?.seconds_east;
    off_have = dt.tzinfo.?.tzOffset.?.seconds_east;
    try testing.expectEqual(off_want, off_have);
    try testing.expectEqualStrings("UTC", dt.tzinfo.?.name());
    try testing.expectEqualStrings("Z", std.mem.sliceTo(dt.tzinfo.?.tzOffset.?.__abbrev_data[0..], 0));
}

test "string -> datetime -> string roundtrip with offset TZ" {
    var string_out = std.ArrayList(u8).init(testing.allocator);
    defer string_out.deinit();
    const string_in = "2023-12-09T01:02:03+09:15";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    const dt = try str.parseToDatetime(directive, string_in);
    try str.formatToString(string_out.writer(), directive, dt);
    try testing.expectEqualStrings(string_in, string_out.items);
    // no name or abbreviation if it's only a UTC offset
    try testing.expectEqual(@as(usize, 0), dt.tzinfo.?.__name_data_len);
    try testing.expectEqualStrings("", std.mem.sliceTo(dt.tzinfo.?.tzOffset.?.__abbrev_data[0..], 0));
}

test "parse ISO" {
    const tzutc = Tz.UTC;
    var dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8 });
    var dt = try str.parseISO8601("2014-08");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23 });
    dt = try str.parseISO8601("2014-08-23");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15 });
    dt = try str.parseISO8601("2014-08-23 12:15");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56 });
    dt = try str.parseISO8601("2014-08-23 12:15:56");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2016, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 60 });
    dt = try str.parseISO8601("2016-12-31T23:59:60");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 123400000 });
    dt = try str.parseISO8601("2014-08-23 12:15:56,1234");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 123000000 });
    dt = try str.parseISO8601("2014-08-23 12:15:56,123");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 123456000 });
    dt = try str.parseISO8601("2014-08-23 12:15:56,123456");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .tzinfo = tzutc });
    dt = try str.parseISO8601("2014-08-23 12:15:56Z");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 123400000, .tzinfo = tzutc });
    dt = try str.parseISO8601("2014-08-23 12:15:56.1234Z");
    try testing.expect(std.meta.eql(dt_ref, dt));

    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 99, .tzinfo = tzutc });
    dt = try str.parseISO8601("2014-08-23 12:15:56.000000099Z");
    try testing.expect(std.meta.eql(dt_ref, dt));

    var tzinfo = try Tz.fromOffset(0, "");
    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .nanosecond = 99, .tzinfo = tzinfo });
    dt = try str.parseISO8601("2014-08-23 12:15:56.000000099+00");
    try testing.expect(std.meta.eql(dt_ref, dt));
    dt = try str.parseISO8601("2014-08-23 12:15:56.000000099+00:00");
    try testing.expect(std.meta.eql(dt_ref, dt));
    dt = try str.parseISO8601("2014-08-23 12:15:56.000000099+00:00:00");
    try testing.expect(std.meta.eql(dt_ref, dt));

    tzinfo = try Tz.fromOffset(2 * 3600 + 15 * 60 + 30, "");
    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .tzinfo = tzinfo });
    dt = try str.parseISO8601("2014-08-23T12:15:56+02:15:30");
    try testing.expect(std.meta.eql(dt_ref, dt));

    tzinfo = try Tz.fromOffset(-2 * 3600, "");
    dt_ref = try Datetime.fromFields(.{ .year = 2014, .month = 8, .day = 23, .hour = 12, .minute = 15, .second = 56, .tzinfo = tzinfo });
    dt = try str.parseISO8601("2014-08-23T12:15:56-0200");
    try testing.expect(std.meta.eql(dt_ref, dt));
}

test "not ISO8601" {
    var err = str.parseISO8601("2014-08-23T12:15:56+-0200"); // invalid offset
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014"); // year-only not allowed
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014-12-32"); // invalid month
    try testing.expectError(error.DayOutOfRange, err);

    err = str.parseISO8601("2014-12-31Z"); // date cannot have tz
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014-12-31-12:15"); // - is not a date/time separator
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014-2-03"); // 1-digit fields not allowed
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("14-02-03"); // 2-digit year not allowed
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014-02-03T13:60"); // invlid minute
    try testing.expectError(error.MinuteOutOfRange, err);

    err = str.parseISO8601("2014-02-03T24:00"); // invlid hour
    try testing.expectError(error.HourOutOfRange, err);

    err = str.parseISO8601("2014-02-03T23:00:00."); // ends with non-numeric
    try testing.expectError(error.InvalidFormat, err);

    err = str.parseISO8601("2014-02-03T23:00:00..314"); // invlid fractional secs separator
    try testing.expectError(error.InvalidFormat, err);
}
