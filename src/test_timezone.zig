const std = @import("std");
const datetime = @import("datetime.zig");
const tz = @import("timezone.zig");
const str = @import("stringIO.zig");

// if (true) return error.SkipZigTest;

test "utc" {
    const utc = tz.UTC;
    try std.testing.expect(utc.tzOffset.?.seconds_east == 0);
    try std.testing.expect(std.mem.eql(u8, utc.name, "UTC"));
}

test "offset tz never changes offset" {
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(999, "hello world");
    try std.testing.expect(std.mem.eql(u8, tzinfo.name, "hello world"));

    tzinfo = try tzinfo.atUnixtime(0);
    try std.testing.expect(tzinfo.tzOffset.?.seconds_east == 999);
    tzinfo = try tzinfo.atUnixtime(@intCast(std.time.timestamp()));
    try std.testing.expect(tzinfo.tzOffset.?.seconds_east == 999);

    var err = tzinfo.loadOffset(-99999, "invalid");
    try std.testing.expectError(tz.TzError.InvalidOffset, err);
    err = tzinfo.loadOffset(99999, "invalid");
    try std.testing.expectError(tz.TzError.InvalidOffset, err);
}

test "offset manifests in Unix time" {
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(3600, "UTC+1");
    // all fields zero, so Unix time has to be adjusted:
    const dt = try datetime.Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    try std.testing.expect(dt.__unix == -3600);
    try std.testing.expect(dt.hour == 0);
    // Unix time zero, so fields have to be adjusted
    const dt_unix = try datetime.Datetime.fromUnix(0, datetime.Unit.second, tzinfo);
    try std.testing.expect(dt_unix.__unix == 0);
    try std.testing.expect(dt_unix.hour == 1);

    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    const string = "1970-01-01T00:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatDatetime(s.writer(), directive, dt);
    try std.testing.expectEqualStrings(string, s.items);
}

test "invalid tzfile name" {
    var err = tz.fromTzfile("this is not a tzname", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
    err = tz.fromTzfile("../test", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
    err = tz.fromTzfile("*=!?:.", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
}

test "mem error" {
    const allocator = std.testing.failing_allocator;
    const err = tz.fromTzfile("UTC", allocator);
    try std.testing.expectError(error.OutOfMemory, err);
}

test "tzfile tz manifests in Unix time" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt = try datetime.Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tzinfo = tzinfo });
    try std.testing.expect(dt.__unix == -3600);
    try std.testing.expect(dt.hour == 0);
    try std.testing.expect(dt.nanosecond == 1); // don't forget the nanoseconds...
}

test "DST transitions" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    var dt_std = try datetime.Datetime.fromUnix(1679792399, datetime.Unit.second, tzinfo);
    var dt_dst = try datetime.Datetime.fromUnix(1679792400, datetime.Unit.second, tzinfo);
    try std.testing.expect(dt_dst.tzinfo.?.is_dst);
    try std.testing.expect(!dt_std.tzinfo.?.is_dst);

    var s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try std.testing.expectEqualStrings("2023-03-26T01:59:59+01:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try std.testing.expectEqualStrings("2023-03-26T03:00:00+02:00", s.items);
    s.deinit();

    // DST on --> DST off (duplicate datetime), 2023-10-29
    dt_dst = try datetime.Datetime.fromUnix(1698541199, datetime.Unit.second, tzinfo);
    dt_std = try datetime.Datetime.fromUnix(1698541200, datetime.Unit.second, tzinfo);
    try std.testing.expect(dt_dst.tzinfo.?.is_dst);
    try std.testing.expect(!dt_std.tzinfo.?.is_dst);

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try std.testing.expectEqualStrings("2023-10-29T02:59:59+02:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try std.testing.expectEqualStrings("2023-10-29T02:00:00+01:00", s.items);
    s.deinit();
}

test "early LMT, late CET" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 1880, .tzinfo = tzinfo });
    var have = @as([]const u8, dt.tzinfo.?.abbreviation[0..3]);
    try std.testing.expectEqualStrings("LMT", have);

    dt = try datetime.Datetime.fromFields(.{ .year = 2039, .month = 8, .tzinfo = tzinfo });
    have = @as([]const u8, dt.tzinfo.?.abbreviation[0..3]);
    try std.testing.expectEqualStrings("CET", have);
}

test "non-existent datetime" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.NonexistentDatetime, dt);

    tzinfo.deinit();
    tzinfo = try tz.fromTzfile("America/Denver", std.testing.allocator);
    dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.NonexistentDatetime, dt);
}

test "ambiguous datetime" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.AmbiguousDatetime, dt);

    tzinfo.deinit();
    tzinfo = try tz.fromTzfile("America/Denver", std.testing.allocator);
    dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.AmbiguousDatetime, dt);
}

test "tz without transitions at UTC+9" {
    var tzinfo = try tz.fromTzfile("Asia/Tokyo", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
}

test "make datetime aware" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try datetime.Datetime.fromUnix(0, datetime.Unit.second, null);
    try std.testing.expect(dt_naive.tzinfo == null);
    const dt_aware = try dt_naive.tzLocalize(tzinfo);
    try std.testing.expect(dt_aware.tzinfo != null);
    try std.testing.expect(dt_aware.__unix != dt_naive.__unix);
    try std.testing.expect(dt_aware.__unix == -3600);
    try std.testing.expect(dt_aware.year == dt_naive.year);
    try std.testing.expect(dt_aware.day == dt_naive.day);
    try std.testing.expect(dt_aware.hour == dt_naive.hour);

    const err = dt_aware.tzLocalize(tzinfo);
    try std.testing.expectError(datetime.ZdtError.TzAlreadyDefined, err);

    const naive_again = try dt_aware.tzLocalize(null);
    try std.testing.expect(std.meta.eql(dt_naive, naive_again));
}

test "convert time zone" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try datetime.Datetime.fromUnix(42, datetime.Unit.nanosecond, null);
    const err = dt_naive.tzConvert(tzinfo);
    try std.testing.expectError(datetime.ZdtError.TzUndefined, err);

    const dt_Berlin = try datetime.Datetime.fromUnix(42, datetime.Unit.nanosecond, tzinfo);

    tzinfo.deinit();
    _ = try tzinfo.loadTzfile("America/New_York", std.testing.allocator);
    const dt_NY = try dt_Berlin.tzConvert(tzinfo);

    try std.testing.expect(dt_Berlin.__unix == dt_NY.__unix);
    try std.testing.expect(dt_Berlin.nanosecond == dt_NY.nanosecond);
    try std.testing.expect(dt_Berlin.hour != dt_NY.hour);
}

test "make TZ with convenience func" {
    const off = try tz.fromOffset(42, "hello_world");
    try std.testing.expect(off.tzFile == null);
    try std.testing.expect(off.tzPosix == null);
    try std.testing.expect(off.tzOffset != null);

    var tzinfo = try tz.fromTzfile("Asia/Kolkata", std.testing.allocator);
    defer _ = tzinfo.deinit();
    try std.testing.expect(tzinfo.tzFile != null);
    try std.testing.expect(tzinfo.tzPosix == null);
    try std.testing.expect(tzinfo.tzOffset == null);
}

test "floor to date changes UTC offset" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 5, .tzinfo = tzinfo });
    var dt_floored = try dt.floorTo(datetime.Timespan.day);
    try std.testing.expectEqual(@as(u5, 0), dt_floored.hour);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.second);
    try std.testing.expectEqual(@as(i20, 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    try std.testing.expectEqual(@as(i20, 7200), dt_floored.tzinfo.?.tzOffset.?.seconds_east);

    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 3, .tzinfo = tzinfo });
    dt_floored = try dt.floorTo(datetime.Timespan.day);
    try std.testing.expectEqual(@as(u5, 0), dt_floored.hour);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.second);
    try std.testing.expectEqual(@as(i20, 7200), dt.tzinfo.?.tzOffset.?.seconds_east);
    try std.testing.expectEqual(@as(i20, 3600), dt_floored.tzinfo.?.tzOffset.?.seconds_east);
}
