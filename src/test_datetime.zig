//! test datetime struct functionality
const std = @import("std");
const zdt = @import("zdt.zig");

test "validate datetime fields" {
    var fields = zdt.datetime_fields{ .year = 2020, .month = 2, .day = 29 };
    _ = try fields.validate();
    fields = zdt.datetime_fields{ .year = 2023, .month = 2, .day = 29 };
    var err = fields.validate();
    try std.testing.expectError(zdt.RangeError.DayOutOfRange, err);

    fields = zdt.datetime_fields{ .year = 2023, .month = 4, .day = 31 };
    err = fields.validate();
    try std.testing.expectError(zdt.RangeError.DayOutOfRange, err);

    fields = zdt.datetime_fields{ .year = 2023, .month = 6, .day = 0 };
    err = fields.validate();
    try std.testing.expectError(zdt.RangeError.DayOutOfRange, err);

    fields = zdt.datetime_fields{ .year = 2023, .month = 13, .day = 1 };
    err = fields.validate();
    try std.testing.expectError(zdt.RangeError.MonthOutOfRange, err);

    fields = zdt.datetime_fields{ .year = 10000, .month = 1, .day = 1 };
    err = fields.validate();
    try std.testing.expectError(zdt.RangeError.YearOutOfRange, err);
}

test "Datetime from empty field struct" {
    const dt = try zdt.Datetime.from_fields(.{});
    try std.testing.expect(dt.year == @as(u14, 1));
    try std.testing.expect(dt.month == @as(u4, 1));
    try std.testing.expect(dt.day == @as(u5, 1));
    try std.testing.expect(dt.tzinfo == null);
}

test "Datetime from populated field struct" {
    const dt = try zdt.Datetime.from_fields(.{ .year = 2023, .month = 12 });
    try std.testing.expect(dt.year == @as(u14, 2023));
    try std.testing.expect(dt.month == @as(u4, 12));
    try std.testing.expect(dt.day == @as(u5, 1));
    try std.testing.expect(dt.tzinfo == null);
}

test "Datetime Unix epoch roundtrip" {
    const unix_from_fields = try zdt.Datetime.from_fields(.{ .year = 1970 });
    const unix_from_seconds = try zdt.Datetime.from_unix(0, zdt.Timeunit.second);
    try std.testing.expect(std.meta.eql(unix_from_fields, unix_from_seconds));
}

test "Dateime from invalid fields" {
    var fields = zdt.datetime_fields{ .year = 2021, .month = 2, .day = 29 };
    var err = zdt.Datetime.from_fields(fields);
    try std.testing.expectError(zdt.RangeError.DayOutOfRange, err);

    fields = zdt.datetime_fields{ .year = 1, .month = 1, .day = 1, .nanosecond = 1000000000 };
    err = zdt.Datetime.from_fields(fields);
    try std.testing.expectError(zdt.RangeError.NanosecondOutOfRange, err);
}

test "Datetime Min Max from fields" {
    var fields = zdt.datetime_fields{ .year = zdt.MIN_YEAR, .month = 1, .day = 1 };
    var dt = try zdt.Datetime.from_fields(fields);
    try std.testing.expect(dt.year == zdt.MIN_YEAR);
    try std.testing.expect(dt.__unix == zdt.UNIX_s_MIN);

    fields = zdt.datetime_fields{
        .year = zdt.MAX_YEAR,
        .month = 12,
        .day = 31,
        .hour = 23,
        .minute = 59,
        .second = 59, // NOTE : prepare for leap seconds
        .nanosecond = 999999999,
    };
    dt = try zdt.Datetime.from_fields(fields);
    try std.testing.expect(dt.year == zdt.MAX_YEAR);
    try std.testing.expect(dt.hour == 23);
    try std.testing.expectEqual(zdt.UNIX_s_MAX, dt.__unix);
}

test "Datetime Min Max fields vs seconds roundtrip" {
    const max_from_seconds = try zdt.Datetime.from_unix(zdt.UNIX_s_MAX, zdt.Timeunit.second);
    const max_from_fields = try zdt.Datetime.from_fields(.{ .year = zdt.MAX_YEAR, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 59 });
    try std.testing.expect(std.meta.eql(max_from_fields, max_from_seconds));

    const min_from_fields = try zdt.Datetime.from_fields(.{ .year = 1 });
    const min_from_seconds = try zdt.Datetime.from_unix(zdt.UNIX_s_MIN, zdt.Timeunit.second);
    try std.testing.expect(std.meta.eql(min_from_fields, min_from_seconds));

    const too_large_s = zdt.Datetime.from_unix(zdt.UNIX_s_MAX + 1, zdt.Timeunit.second);
    try std.testing.expectError(zdt.RangeError.UnixOutOfRange, too_large_s);
    const too_large_ns = zdt.Datetime.from_unix(@as(i72, zdt.UNIX_s_MAX + 1) * std.time.ns_per_s, zdt.Timeunit.second);
    try std.testing.expectError(zdt.RangeError.UnixOutOfRange, too_large_ns);
    const too_small_s = zdt.Datetime.from_unix(zdt.UNIX_s_MIN - 1, zdt.Timeunit.second);
    try std.testing.expectError(zdt.RangeError.UnixOutOfRange, too_small_s);
    const too_small_ns = zdt.Datetime.from_unix(@as(i72, zdt.UNIX_s_MIN - 1) * std.time.ns_per_s, zdt.Timeunit.second);
    try std.testing.expectError(zdt.RangeError.UnixOutOfRange, too_small_ns);
}

test "Datetime format basic naive" {
    var str = std.ArrayList(u8).init(std.testing.allocator);
    defer str.deinit();

    var dt = try zdt.Datetime.from_fields(.{ .year = 2023, .month = 12, .day = 31 });
    try dt.format("", .{}, str.writer());
    try std.testing.expectEqualStrings("2023-12-31T00:00:00", str.items);

    str.clearRetainingCapacity();
    dt = try zdt.Datetime.from_fields(.{ .year = 2023, .month = 12, .day = 31, .nanosecond = 1 });
    try dt.format("", .{}, str.writer());
    try std.testing.expectEqualStrings("2023-12-31T00:00:00.000000001", str.items);
}

// ---vv--- test generated with Python script ---vv---

test "full range random unix seconds <--> fields" {
    var dt_from_unix = try zdt.Datetime.from_unix(0, zdt.Timeunit.second);
    try std.testing.expect(dt_from_unix.year == 1970);

    // 6784-12-06T15:35:41+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(151944564941, zdt.Timeunit.second);
    var dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6784, .month = 12, .day = 6, .hour = 15, .minute = 35, .second = 41, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0738-10-03T01:48:05+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-38854419115, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 738, .month = 10, .day = 3, .hour = 1, .minute = 48, .second = 5, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8508-12-01T07:42:26+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(206348283746, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8508, .month = 12, .day = 1, .hour = 7, .minute = 42, .second = 26, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6190-06-17T21:30:44+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(133184899844, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6190, .month = 6, .day = 17, .hour = 21, .minute = 30, .second = 44, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3799-05-09T19:35:47+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(57728835347, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3799, .month = 5, .day = 9, .hour = 19, .minute = 35, .second = 47, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2383-06-05T16:53:10+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(13046460790, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2383, .month = 6, .day = 5, .hour = 16, .minute = 53, .second = 10, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2353-02-04T19:39:31+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(12089331571, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2353, .month = 2, .day = 4, .hour = 19, .minute = 39, .second = 31, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1737-02-03T11:11:53+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-7349834887, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1737, .month = 2, .day = 3, .hour = 11, .minute = 11, .second = 53, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9379-10-06T01:35:38+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(233829509738, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9379, .month = 10, .day = 6, .hour = 1, .minute = 35, .second = 38, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2573-08-16T18:23:07+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(19048587787, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2573, .month = 8, .day = 16, .hour = 18, .minute = 23, .second = 7, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1676-06-08T18:07:21+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-9263915559, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1676, .month = 6, .day = 8, .hour = 18, .minute = 7, .second = 21, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1325-04-02T13:26:19+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-20346287621, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1325, .month = 4, .day = 2, .hour = 13, .minute = 26, .second = 19, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5810-05-20T08:24:10+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(121190718250, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5810, .month = 5, .day = 20, .hour = 8, .minute = 24, .second = 10, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9728-07-05T11:39:03+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(244834918743, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9728, .month = 7, .day = 5, .hour = 11, .minute = 39, .second = 3, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6139-04-21T00:25:24+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(131570439924, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6139, .month = 4, .day = 21, .hour = 0, .minute = 25, .second = 24, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5504-03-06T14:01:06+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(111527848866, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5504, .month = 3, .day = 6, .hour = 14, .minute = 1, .second = 6, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3663-12-02T00:52:12+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(53454905532, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3663, .month = 12, .day = 2, .hour = 0, .minute = 52, .second = 12, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9659-09-15T03:17:21+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(242663656641, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9659, .month = 9, .day = 15, .hour = 3, .minute = 17, .second = 21, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 7687-08-22T09:12:38+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(180431313158, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 7687, .month = 8, .day = 22, .hour = 9, .minute = 12, .second = 38, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9101-07-06T14:03:10+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(225048722590, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9101, .month = 7, .day = 6, .hour = 14, .minute = 3, .second = 10, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0989-03-03T00:43:47+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-30952019773, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 989, .month = 3, .day = 3, .hour = 0, .minute = 43, .second = 47, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1500-01-13T23:35:04+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-14830647896, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1500, .month = 1, .day = 13, .hour = 23, .minute = 35, .second = 4, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5835-05-17T02:12:58+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(121979355178, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5835, .month = 5, .day = 17, .hour = 2, .minute = 12, .second = 58, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1208-04-16T12:24:08+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-24037212952, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1208, .month = 4, .day = 16, .hour = 12, .minute = 24, .second = 8, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3889-02-05T15:52:47+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(60560927567, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3889, .month = 2, .day = 5, .hour = 15, .minute = 52, .second = 47, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2582-07-10T12:57:54+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(19329368274, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2582, .month = 7, .day = 10, .hour = 12, .minute = 57, .second = 54, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9501-05-12T20:56:29+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(237666776189, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9501, .month = 5, .day = 12, .hour = 20, .minute = 56, .second = 29, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1559-02-04T15:41:56+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-12966941884, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1559, .month = 2, .day = 4, .hour = 15, .minute = 41, .second = 56, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8566-04-17T03:18:35+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(208158866315, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8566, .month = 4, .day = 17, .hour = 3, .minute = 18, .second = 35, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5187-09-22T12:58:57+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(101541560337, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5187, .month = 9, .day = 22, .hour = 12, .minute = 58, .second = 57, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5111-10-23T14:52:39+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(99145867959, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5111, .month = 10, .day = 23, .hour = 14, .minute = 52, .second = 39, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2138-09-12T09:40:13+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(5323570813, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2138, .month = 9, .day = 12, .hour = 9, .minute = 40, .second = 13, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5791-10-18T18:14:02+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(120604270442, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5791, .month = 10, .day = 18, .hour = 18, .minute = 14, .second = 2, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3613-03-10T15:41:53+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(51854053313, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3613, .month = 3, .day = 10, .hour = 15, .minute = 41, .second = 53, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9610-03-30T09:27:46+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(241102776466, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9610, .month = 3, .day = 30, .hour = 9, .minute = 27, .second = 46, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4980-08-26T07:25:43+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(95007021943, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4980, .month = 8, .day = 26, .hour = 7, .minute = 25, .second = 43, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1558-09-09T11:46:13+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-12979743227, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1558, .month = 9, .day = 9, .hour = 11, .minute = 46, .second = 13, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5497-06-21T07:47:49+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(111316232869, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5497, .month = 6, .day = 21, .hour = 7, .minute = 47, .second = 49, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4162-05-30T20:32:50+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(69185824370, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4162, .month = 5, .day = 30, .hour = 20, .minute = 32, .second = 50, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3170-11-12T13:25:32+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(37895606732, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3170, .month = 11, .day = 12, .hour = 13, .minute = 25, .second = 32, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0570-10-28T10:53:41+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-44153730379, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 570, .month = 10, .day = 28, .hour = 10, .minute = 53, .second = 41, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4581-09-28T14:43:03+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(82418654583, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4581, .month = 9, .day = 28, .hour = 14, .minute = 43, .second = 3, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1154-09-04T15:23:40+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-25729173380, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1154, .month = 9, .day = 4, .hour = 15, .minute = 23, .second = 40, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2281-09-30T00:13:44+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(9837764024, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2281, .month = 9, .day = 30, .hour = 0, .minute = 13, .second = 44, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2706-04-10T14:44:59+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(23234481899, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2706, .month = 4, .day = 10, .hour = 14, .minute = 44, .second = 59, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0671-01-31T14:20:56+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-40989836344, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 671, .month = 1, .day = 31, .hour = 14, .minute = 20, .second = 56, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1476-09-06T14:54:32+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-15567584728, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1476, .month = 9, .day = 6, .hour = 14, .minute = 54, .second = 32, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9215-10-31T21:26:09+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(228656381169, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9215, .month = 10, .day = 31, .hour = 21, .minute = 26, .second = 9, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9021-04-03T15:24:45+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(222516084285, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9021, .month = 4, .day = 3, .hour = 15, .minute = 24, .second = 45, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4194-07-12T08:53:57+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(70199340837, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4194, .month = 7, .day = 12, .hour = 8, .minute = 53, .second = 57, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3791-05-17T10:57:23+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(57477034643, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3791, .month = 5, .day = 17, .hour = 10, .minute = 57, .second = 23, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 7343-09-05T08:36:04+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(169576878964, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 7343, .month = 9, .day = 5, .hour = 8, .minute = 36, .second = 4, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4843-06-22T05:34:42+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(90678029682, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4843, .month = 6, .day = 22, .hour = 5, .minute = 34, .second = 42, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8636-10-03T14:24:01+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(210382496641, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8636, .month = 10, .day = 3, .hour = 14, .minute = 24, .second = 1, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6233-07-27T12:53:46+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(134545236826, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6233, .month = 7, .day = 27, .hour = 12, .minute = 53, .second = 46, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5592-05-25T20:07:12+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(114311851632, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5592, .month = 5, .day = 25, .hour = 20, .minute = 7, .second = 12, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1989-10-31T09:19:02+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(625828742, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1989, .month = 10, .day = 31, .hour = 9, .minute = 19, .second = 2, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5803-01-21T02:50:47+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(120959491847, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5803, .month = 1, .day = 21, .hour = 2, .minute = 50, .second = 47, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3382-06-20T12:07:30+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(44573198850, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3382, .month = 6, .day = 20, .hour = 12, .minute = 7, .second = 30, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0306-04-14T21:44:13+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-52501832147, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 306, .month = 4, .day = 14, .hour = 21, .minute = 44, .second = 13, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4728-01-12T16:39:14+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(87035013554, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4728, .month = 1, .day = 12, .hour = 16, .minute = 39, .second = 14, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6427-10-21T19:48:36+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(140674736916, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6427, .month = 10, .day = 21, .hour = 19, .minute = 48, .second = 36, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2967-04-16T14:18:32+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(31471424312, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2967, .month = 4, .day = 16, .hour = 14, .minute = 18, .second = 32, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 7395-10-10T00:31:25+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(171220869085, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 7395, .month = 10, .day = 10, .hour = 0, .minute = 31, .second = 25, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1064-10-06T03:32:19+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-28566505661, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1064, .month = 10, .day = 6, .hour = 3, .minute = 32, .second = 19, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3906-10-25T22:41:10+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(61119960070, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3906, .month = 10, .day = 25, .hour = 22, .minute = 41, .second = 10, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1318-07-20T16:42:20+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-20557783060, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1318, .month = 7, .day = 20, .hour = 16, .minute = 42, .second = 20, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2046-03-02T03:35:04+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2403574504, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2046, .month = 3, .day = 2, .hour = 3, .minute = 35, .second = 4, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3353-11-16T11:42:40+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(43670922160, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3353, .month = 11, .day = 16, .hour = 11, .minute = 42, .second = 40, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2120-12-02T19:42:23+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(4762611743, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2120, .month = 12, .day = 2, .hour = 19, .minute = 42, .second = 23, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1551-05-16T02:11:33+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-13210724907, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1551, .month = 5, .day = 16, .hour = 2, .minute = 11, .second = 33, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2039-11-18T12:31:29+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2205232289, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2039, .month = 11, .day = 18, .hour = 12, .minute = 31, .second = 29, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3270-05-25T00:40:23+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(41036546423, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3270, .month = 5, .day = 25, .hour = 0, .minute = 40, .second = 23, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8320-02-04T07:25:46+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(200389533946, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8320, .month = 2, .day = 4, .hour = 7, .minute = 25, .second = 46, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1062-09-13T05:11:55+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-28631645285, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1062, .month = 9, .day = 13, .hour = 5, .minute = 11, .second = 55, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9395-02-23T03:10:43+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(234314997043, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9395, .month = 2, .day = 23, .hour = 3, .minute = 10, .second = 43, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1125-03-12T20:16:34+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-26659511006, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1125, .month = 3, .day = 12, .hour = 20, .minute = 16, .second = 34, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1255-12-22T21:49:45+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-22532436615, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1255, .month = 12, .day = 22, .hour = 21, .minute = 49, .second = 45, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 5260-12-05T02:21:12+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(103851685272, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 5260, .month = 12, .day = 5, .hour = 2, .minute = 21, .second = 12, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 7534-04-18T00:53:44+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(175592105624, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 7534, .month = 4, .day = 18, .hour = 0, .minute = 53, .second = 44, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0978-04-04T12:56:05+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-31296366235, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 978, .month = 4, .day = 4, .hour = 12, .minute = 56, .second = 5, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8099-07-27T19:33:02+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(193430575982, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8099, .month = 7, .day = 27, .hour = 19, .minute = 33, .second = 2, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6940-08-09T22:00:33+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(156857205633, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6940, .month = 8, .day = 9, .hour = 22, .minute = 0, .second = 33, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 4519-07-03T22:16:14+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(80454550574, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 4519, .month = 7, .day = 3, .hour = 22, .minute = 16, .second = 14, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8266-09-13T03:02:35+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(198704631755, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8266, .month = 9, .day = 13, .hour = 3, .minute = 2, .second = 35, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9925-05-12T09:42:14+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(251046898934, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9925, .month = 5, .day = 12, .hour = 9, .minute = 42, .second = 14, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 3631-03-16T03:42:10+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(52422522130, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 3631, .month = 3, .day = 16, .hour = 3, .minute = 42, .second = 10, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2815-01-28T13:34:24+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(26668013664, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2815, .month = 1, .day = 28, .hour = 13, .minute = 34, .second = 24, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2838-02-08T16:15:13+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(27394820113, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2838, .month = 2, .day = 8, .hour = 16, .minute = 15, .second = 13, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9166-06-07T12:20:01+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(227097433201, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9166, .month = 6, .day = 7, .hour = 12, .minute = 20, .second = 1, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2076-08-25T18:42:55+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3365606575, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2076, .month = 8, .day = 25, .hour = 18, .minute = 42, .second = 55, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 0160-11-23T14:14:49+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-57089785511, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 160, .month = 11, .day = 23, .hour = 14, .minute = 14, .second = 49, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 6718-08-13T07:38:15+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(149851755495, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 6718, .month = 8, .day = 13, .hour = 7, .minute = 38, .second = 15, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2621-02-04T01:16:51+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(20546529411, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2621, .month = 2, .day = 4, .hour = 1, .minute = 16, .second = 51, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 7896-08-12T20:25:46+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(187025919946, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 7896, .month = 8, .day = 12, .hour = 20, .minute = 25, .second = 46, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1462-12-14T13:24:43+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-16000886117, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1462, .month = 12, .day = 14, .hour = 13, .minute = 24, .second = 43, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 9398-04-07T04:32:48+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(234413411568, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 9398, .month = 4, .day = 7, .hour = 4, .minute = 32, .second = 48, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2352-12-19T08:40:51+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(12085231251, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2352, .month = 12, .day = 19, .hour = 8, .minute = 40, .second = 51, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 8432-12-13T18:20:07+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(203951067607, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 8432, .month = 12, .day = 13, .hour = 18, .minute = 20, .second = 7, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2263-03-02T05:04:36+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(9251384676, zdt.Timeunit.second);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2263, .month = 3, .day = 2, .hour = 5, .minute = 4, .second = 36, .nanosecond = 0 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
}

test "full range random unix nanoseconds <--> fields" {
    var dt_from_unix = try zdt.Datetime.from_unix(0, zdt.Timeunit.nanosecond);
    try std.testing.expect(dt_from_unix.year == 1970);
    try std.testing.expect(dt_from_unix.nanosecond == 0);
    dt_from_unix = try zdt.Datetime.from_unix(999999999, zdt.Timeunit.nanosecond);
    try std.testing.expect(dt_from_unix.year == 1970);
    try std.testing.expect(dt_from_unix.nanosecond == 999999999);
    dt_from_unix = try zdt.Datetime.from_unix(1999999999, zdt.Timeunit.nanosecond);
    try std.testing.expect(dt_from_unix.year == 1970);
    try std.testing.expect(dt_from_unix.second == 1);
    try std.testing.expect(dt_from_unix.nanosecond == 999999999);

    // 2009-12-16T19:31:59.646669+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1260991919646669000, zdt.Timeunit.nanosecond);
    var dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2009, .month = 12, .day = 16, .hour = 19, .minute = 31, .second = 59, .nanosecond = 646669000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1911-07-23T11:20:24.738901+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1844339975261099000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1911, .month = 7, .day = 23, .hour = 11, .minute = 20, .second = 24, .nanosecond = 738901000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2038-09-11T23:19:08.439138+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2167859948439138000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2038, .month = 9, .day = 11, .hour = 23, .minute = 19, .second = 8, .nanosecond = 439138000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2002-03-13T14:52:55.090692+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1016031175090692000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2002, .month = 3, .day = 13, .hour = 14, .minute = 52, .second = 55, .nanosecond = 90692000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1962-05-08T16:01:23.383827+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-241430316616173000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1962, .month = 5, .day = 8, .hour = 16, .minute = 1, .second = 23, .nanosecond = 383827000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1939-10-03T07:13:45.494646+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-954521174505354000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1939, .month = 10, .day = 3, .hour = 7, .minute = 13, .second = 45, .nanosecond = 494646000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1939-11-21T12:04:45.988467+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-950270114011533000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1939, .month = 11, .day = 21, .hour = 12, .minute = 4, .second = 45, .nanosecond = 988467000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1927-01-26T02:49:32.179065+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1354828227820935000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1927, .month = 1, .day = 26, .hour = 2, .minute = 49, .second = 32, .nanosecond = 179065000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2052-01-03T18:07:31.344746+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2587918051344746000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2052, .month = 1, .day = 3, .hour = 18, .minute = 7, .second = 31, .nanosecond = 344746000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2071-10-19T07:39:58.251422+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3212465998251422000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2071, .month = 10, .day = 19, .hour = 7, .minute = 39, .second = 58, .nanosecond = 251422000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1941-12-12T17:59:55.400459+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-885276004599541000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1941, .month = 12, .day = 12, .hour = 17, .minute = 59, .second = 55, .nanosecond = 400459000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1928-03-11T01:20:53.388505+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1319409546611495000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1928, .month = 3, .day = 11, .hour = 1, .minute = 20, .second = 53, .nanosecond = 388505000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1921-01-18T16:18:51.962619+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1544773268037381000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1921, .month = 1, .day = 18, .hour = 16, .minute = 18, .second = 51, .nanosecond = 962619000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1994-04-01T01:17:06.051626+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(765163026051626000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1994, .month = 4, .day = 1, .hour = 1, .minute = 17, .second = 6, .nanosecond = 51626000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2059-10-14T13:49:22.883671+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2833364962883671000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2059, .month = 10, .day = 14, .hour = 13, .minute = 49, .second = 22, .nanosecond = 883671000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2000-12-24T17:43:17.644788+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(977679797644788000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2000, .month = 12, .day = 24, .hour = 17, .minute = 43, .second = 17, .nanosecond = 644788000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1990-04-02T11:56:58.338978+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(639057418338978000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1990, .month = 4, .day = 2, .hour = 11, .minute = 56, .second = 58, .nanosecond = 338978000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2082-10-17T03:41:15.141817+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3559434075141817000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2082, .month = 10, .day = 17, .hour = 3, .minute = 41, .second = 15, .nanosecond = 141817000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1958-05-13T19:16:37.223356+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-367217002776644000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1958, .month = 5, .day = 13, .hour = 19, .minute = 16, .second = 37, .nanosecond = 223356000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2057-09-14T15:07:06.567617+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2767705626567617000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2057, .month = 9, .day = 14, .hour = 15, .minute = 7, .second = 6, .nanosecond = 567617000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2026-05-10T18:56:51.511302+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1778439411511302000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2026, .month = 5, .day = 10, .hour = 18, .minute = 56, .second = 51, .nanosecond = 511302000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2048-10-22T02:44:34.330526+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2486947474330526000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2048, .month = 10, .day = 22, .hour = 2, .minute = 44, .second = 34, .nanosecond = 330526000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1917-10-11T14:55:02.369219+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1648026297630781000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1917, .month = 10, .day = 11, .hour = 14, .minute = 55, .second = 2, .nanosecond = 369219000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1926-08-16T13:52:18.242728+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1368871661757272000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1926, .month = 8, .day = 16, .hour = 13, .minute = 52, .second = 18, .nanosecond = 242728000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2078-06-19T23:11:40.693121+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3422905900693121000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2078, .month = 6, .day = 19, .hour = 23, .minute = 11, .second = 40, .nanosecond = 693121000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2074-08-26T06:08:52.794693+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3302489332794693000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2074, .month = 8, .day = 26, .hour = 6, .minute = 8, .second = 52, .nanosecond = 794693000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1995-02-01T09:03:23.166506+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(791629403166506000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1995, .month = 2, .day = 1, .hour = 9, .minute = 3, .second = 23, .nanosecond = 166506000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1917-12-24T02:58:03.872232+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1641675716127768000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1917, .month = 12, .day = 24, .hour = 2, .minute = 58, .second = 3, .nanosecond = 872232000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1963-04-13T14:51:41.846095+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-212058498153905000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1963, .month = 4, .day = 13, .hour = 14, .minute = 51, .second = 41, .nanosecond = 846095000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1940-09-03T01:37:02.552018+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-925510977447982000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1940, .month = 9, .day = 3, .hour = 1, .minute = 37, .second = 2, .nanosecond = 552018000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2054-12-25T17:09:08.538237+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2681831348538237000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2054, .month = 12, .day = 25, .hour = 17, .minute = 9, .second = 8, .nanosecond = 538237000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1926-01-14T05:58:22.968388+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1387389697031612000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1926, .month = 1, .day = 14, .hour = 5, .minute = 58, .second = 22, .nanosecond = 968388000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2039-08-28T03:38:28.654731+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2198115508654731000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2039, .month = 8, .day = 28, .hour = 3, .minute = 38, .second = 28, .nanosecond = 654731000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1986-01-15T19:03:18.617873+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(506199798617873000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1986, .month = 1, .day = 15, .hour = 19, .minute = 3, .second = 18, .nanosecond = 617873000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1983-02-01T04:59:58.158263+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(412923598158263000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1983, .month = 2, .day = 1, .hour = 4, .minute = 59, .second = 58, .nanosecond = 158263000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1935-08-17T13:10:39.484285+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1084790960515715000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1935, .month = 8, .day = 17, .hour = 13, .minute = 10, .second = 39, .nanosecond = 484285000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1994-12-23T05:53:09.473898+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(788161989473898000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1994, .month = 12, .day = 23, .hour = 5, .minute = 53, .second = 9, .nanosecond = 473898000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1957-12-31T19:25:58.854337+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-378707641145663000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1957, .month = 12, .day = 31, .hour = 19, .minute = 25, .second = 58, .nanosecond = 854337000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2056-03-11T17:28:58.767250+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2720021338767250000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2056, .month = 3, .day = 11, .hour = 17, .minute = 28, .second = 58, .nanosecond = 767250000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1982-02-08T07:06:29.748343+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(381999989748343000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1982, .month = 2, .day = 8, .hour = 7, .minute = 6, .second = 29, .nanosecond = 748343000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1926-02-26T15:29:56.616453+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1383640203383547000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1926, .month = 2, .day = 26, .hour = 15, .minute = 29, .second = 56, .nanosecond = 616453000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1990-06-30T03:05:33.411749+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(646715133411749000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1990, .month = 6, .day = 30, .hour = 3, .minute = 5, .second = 33, .nanosecond = 411749000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1969-02-07T16:08:12.436850+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-28281107563150000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1969, .month = 2, .day = 7, .hour = 16, .minute = 8, .second = 12, .nanosecond = 436850000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1952-06-25T07:03:56.293324+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-552848163706676000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1952, .month = 6, .day = 25, .hour = 7, .minute = 3, .second = 56, .nanosecond = 293324000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1909-05-31T09:00:00.581045+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1911999599418955000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1909, .month = 5, .day = 31, .hour = 9, .minute = 0, .second = 0, .nanosecond = 581045000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1974-03-24T20:53:19.321207+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(133390399321207000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1974, .month = 3, .day = 24, .hour = 20, .minute = 53, .second = 19, .nanosecond = 321207000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1919-09-21T03:31:38.464124+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1586723301535876000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1919, .month = 9, .day = 21, .hour = 3, .minute = 31, .second = 38, .nanosecond = 464124000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2093-09-21T22:56:40.344224+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3904412200344224000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2093, .month = 9, .day = 21, .hour = 22, .minute = 56, .second = 40, .nanosecond = 344224000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1937-03-03T21:53:42.421688+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1036029977578312000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1937, .month = 3, .day = 3, .hour = 21, .minute = 53, .second = 42, .nanosecond = 421688000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1942-09-08T15:01:03.777259+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-861958736222741000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1942, .month = 9, .day = 8, .hour = 15, .minute = 1, .second = 3, .nanosecond = 777259000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1911-01-12T10:00:30.657224+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1860933569342776000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1911, .month = 1, .day = 12, .hour = 10, .minute = 0, .second = 30, .nanosecond = 657224000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1922-11-27T21:10:54.517544+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1486176545482456000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1922, .month = 11, .day = 27, .hour = 21, .minute = 10, .second = 54, .nanosecond = 517544000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2099-08-09T10:19:24.395638+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(4089953964395638000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2099, .month = 8, .day = 9, .hour = 10, .minute = 19, .second = 24, .nanosecond = 395638000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2095-02-01T17:27:23.945401+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3947419643945401000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2095, .month = 2, .day = 1, .hour = 17, .minute = 27, .second = 23, .nanosecond = 945401000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2049-09-22T20:23:16.138993+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2515954996138993000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2049, .month = 9, .day = 22, .hour = 20, .minute = 23, .second = 16, .nanosecond = 138993000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2048-12-06T14:52:11.735357+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2490879131735357000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2048, .month = 12, .day = 6, .hour = 14, .minute = 52, .second = 11, .nanosecond = 735357000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1967-03-22T01:08:44.001829+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-87778275998171000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1967, .month = 3, .day = 22, .hour = 1, .minute = 8, .second = 44, .nanosecond = 1829000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1961-06-04T17:37:23.904915+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-270627756095085000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1961, .month = 6, .day = 4, .hour = 17, .minute = 37, .second = 23, .nanosecond = 904915000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2093-12-09T05:45:37.238534+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3911175937238534000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2093, .month = 12, .day = 9, .hour = 5, .minute = 45, .second = 37, .nanosecond = 238534000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2019-09-18T21:39:02.966900+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1568842742966900000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2019, .month = 9, .day = 18, .hour = 21, .minute = 39, .second = 2, .nanosecond = 966900000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1978-07-21T17:00:24.395890+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(269888424395890000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1978, .month = 7, .day = 21, .hour = 17, .minute = 0, .second = 24, .nanosecond = 395890000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2040-08-13T07:56:21.264001+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2228457381264001000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2040, .month = 8, .day = 13, .hour = 7, .minute = 56, .second = 21, .nanosecond = 264001000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2083-01-05T18:52:04.088656+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3566400724088656000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2083, .month = 1, .day = 5, .hour = 18, .minute = 52, .second = 4, .nanosecond = 88656000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2099-11-11T12:52:38.757617+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(4098084758757617000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2099, .month = 11, .day = 11, .hour = 12, .minute = 52, .second = 38, .nanosecond = 757617000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2002-01-01T14:23:47.161690+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1009895027161690000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2002, .month = 1, .day = 1, .hour = 14, .minute = 23, .second = 47, .nanosecond = 161690000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1992-07-27T20:11:59.902064+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(712267919902064000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1992, .month = 7, .day = 27, .hour = 20, .minute = 11, .second = 59, .nanosecond = 902064000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1932-12-04T04:38:15.622278+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1170012104377722000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1932, .month = 12, .day = 4, .hour = 4, .minute = 38, .second = 15, .nanosecond = 622278000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2067-07-26T12:18:24.620404+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3078908304620404000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2067, .month = 7, .day = 26, .hour = 12, .minute = 18, .second = 24, .nanosecond = 620404000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1995-09-11T23:14:06.854663+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(810861246854663000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1995, .month = 9, .day = 11, .hour = 23, .minute = 14, .second = 6, .nanosecond = 854663000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1954-05-05T00:23:27.410434+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-494206592589566000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1954, .month = 5, .day = 5, .hour = 0, .minute = 23, .second = 27, .nanosecond = 410434000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1904-08-17T18:19:32.155693+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-2062993227844307000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1904, .month = 8, .day = 17, .hour = 18, .minute = 19, .second = 32, .nanosecond = 155693000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1977-05-12T16:50:17.539762+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(232303817539762000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1977, .month = 5, .day = 12, .hour = 16, .minute = 50, .second = 17, .nanosecond = 539762000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2006-03-13T05:51:39.051540+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1142229099051540000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2006, .month = 3, .day = 13, .hour = 5, .minute = 51, .second = 39, .nanosecond = 51540000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1948-08-29T18:04:50.177592+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-673422909822408000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1948, .month = 8, .day = 29, .hour = 18, .minute = 4, .second = 50, .nanosecond = 177592000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2021-08-18T03:29:56.942557+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1629257396942557000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2021, .month = 8, .day = 18, .hour = 3, .minute = 29, .second = 56, .nanosecond = 942557000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1917-10-02T14:26:43.835459+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1648805596164541000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1917, .month = 10, .day = 2, .hour = 14, .minute = 26, .second = 43, .nanosecond = 835459000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1962-06-12T03:44:46.844678+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-238450513155322000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1962, .month = 6, .day = 12, .hour = 3, .minute = 44, .second = 46, .nanosecond = 844678000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2081-01-07T00:42:12.532841+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3503436132532841000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2081, .month = 1, .day = 7, .hour = 0, .minute = 42, .second = 12, .nanosecond = 532841000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2071-11-16T07:01:19.345325+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3214882879345325000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2071, .month = 11, .day = 16, .hour = 7, .minute = 1, .second = 19, .nanosecond = 345325000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1921-02-14T04:08:58.035948+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1542484261964052000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1921, .month = 2, .day = 14, .hour = 4, .minute = 8, .second = 58, .nanosecond = 35948000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1935-07-10T05:43:14.670056+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1088101005329944000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1935, .month = 7, .day = 10, .hour = 5, .minute = 43, .second = 14, .nanosecond = 670056000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1953-10-23T06:50:17.581232+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-510944982418768000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1953, .month = 10, .day = 23, .hour = 6, .minute = 50, .second = 17, .nanosecond = 581232000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1934-03-02T06:01:09.373727+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1130867930626273000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1934, .month = 3, .day = 2, .hour = 6, .minute = 1, .second = 9, .nanosecond = 373727000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1926-02-16T04:53:42.502613+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1384542377497387000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1926, .month = 2, .day = 16, .hour = 4, .minute = 53, .second = 42, .nanosecond = 502613000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1933-02-14T20:07:02.245281+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1163735577754719000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1933, .month = 2, .day = 14, .hour = 20, .minute = 7, .second = 2, .nanosecond = 245281000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2072-10-28T19:00:57.651475+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3244906857651475000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2072, .month = 10, .day = 28, .hour = 19, .minute = 0, .second = 57, .nanosecond = 651475000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1955-07-18T01:35:16.883575+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-456272683116425000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1955, .month = 7, .day = 18, .hour = 1, .minute = 35, .second = 16, .nanosecond = 883575000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2036-10-14T01:40:38.788090+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2107561238788090000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2036, .month = 10, .day = 14, .hour = 1, .minute = 40, .second = 38, .nanosecond = 788090000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1917-06-09T02:58:49.667227+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1658782870332773000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1917, .month = 6, .day = 9, .hour = 2, .minute = 58, .second = 49, .nanosecond = 667227000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2093-11-25T23:16:01.059320+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3910029361059320000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2093, .month = 11, .day = 25, .hour = 23, .minute = 16, .second = 1, .nanosecond = 59320000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2055-05-04T12:27:31.336243+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(2693046451336243000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2055, .month = 5, .day = 4, .hour = 12, .minute = 27, .second = 31, .nanosecond = 336243000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2077-02-18T12:56:44.024597+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3380878604024597000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2077, .month = 2, .day = 18, .hour = 12, .minute = 56, .second = 44, .nanosecond = 24597000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1919-12-25T22:16:10.105890+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1578447829894110000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1919, .month = 12, .day = 25, .hour = 22, .minute = 16, .second = 10, .nanosecond = 105890000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1920-07-18T00:43:57.276281+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1560726962723719000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1920, .month = 7, .day = 18, .hour = 0, .minute = 43, .second = 57, .nanosecond = 276281000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1985-12-06T15:42:55.167640+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(502731775167640000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1985, .month = 12, .day = 6, .hour = 15, .minute = 42, .second = 55, .nanosecond = 167640000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2024-06-19T03:48:06.627736+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1718768886627736000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2024, .month = 6, .day = 19, .hour = 3, .minute = 48, .second = 6, .nanosecond = 627736000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 1917-06-04T16:03:32.856933+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(-1659167787143067000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 1917, .month = 6, .day = 4, .hour = 16, .minute = 3, .second = 32, .nanosecond = 856933000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2033-05-01T10:36:39.792238+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(1998556599792238000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2033, .month = 5, .day = 1, .hour = 10, .minute = 36, .second = 39, .nanosecond = 792238000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2070-04-02T12:32:44.075274+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(3163667564075274000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2070, .month = 4, .day = 2, .hour = 12, .minute = 32, .second = 44, .nanosecond = 75274000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));

    // 2099-08-09T09:22:20.224880+00:00 :
    dt_from_unix = try zdt.Datetime.from_unix(4089950540224880000, zdt.Timeunit.nanosecond);
    dt_from_fields = try zdt.Datetime.from_fields(.{ .year = 2099, .month = 8, .day = 9, .hour = 9, .minute = 22, .second = 20, .nanosecond = 224880000 });
    try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
}
