//! test timezone from a users's perspective (no internal functionality)
const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const ZdtError = zdt.ZdtError;
const TzError = zdt.TzError;
const str = zdt.stringIO;

const log = std.log.scoped(.test_timezone);

test "utc" {
    var utc = Tz.UTC;
    try testing.expect(utc.tzOffset.?.seconds_east == 0);
    try testing.expectEqualStrings(utc.name(), "UTC");
    try testing.expectEqualStrings(utc.abbreviation(), "Z");
}

test "offset tz never changes offset" {
    var tzinfo = try Tz.fromOffset(999, "hello world");
    try testing.expect(std.mem.eql(u8, tzinfo.name(), "hello world"));

    var utoff = try tzinfo.atUnixtime(0);
    try testing.expect(utoff.seconds_east == 999);
    utoff = try tzinfo.atUnixtime(@intCast(std.time.timestamp()));
    try testing.expect(utoff.seconds_east == 999);

    var err: zdt.ZdtError!zdt.Timezone = Tz.fromOffset(-99999, "invalid");
    try testing.expectError(TzError.InvalidOffset, err);
    err = Tz.fromOffset(99999, "invalid");
    try testing.expectError(TzError.InvalidOffset, err);
}

test "offset manifests in Unix time" {
    const tzinfo = try Tz.fromOffset(3600, "UTC+1");
    // all fields zero, so Unix time has to be adjusted:
    const dt = try Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    try testing.expect(dt.__unix == -3600);
    try testing.expect(dt.hour == 0);
    // Unix time zero, so fields have to be adjusted
    const dt_unix = try Datetime.fromUnix(0, Duration.Resolution.second, tzinfo);
    try testing.expect(dt_unix.__unix == 0);
    try testing.expect(dt_unix.hour == 1);

    var s = std.ArrayList(u8).init(testing.allocator);
    defer s.deinit();
    const string = "1970-01-01T00:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatToString(s.writer(), directive, dt);
    try testing.expectEqualStrings(string, s.items);
}

test "mem error" {
    const allocator = testing.failing_allocator;
    const err = Tz.fromTzfile("UTC", allocator);
    try testing.expectError(error.OutOfMemory, err);
}

test "tzfile tz manifests in Unix time" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tzinfo = tzinfo });
    try testing.expect(dt.__unix == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tzinfo != null);
    try testing.expectEqualStrings(dt.tzinfo.?.name(), "Europe/Berlin");
    try testing.expectEqualStrings("CET", std.mem.sliceTo(dt.tzinfo.?.tzOffset.?.__abbrev_data[0..], 0));
}

test "local tz db, from specified or default prefix" {
    // NOTE : Windows does not use the IANA db, so we cannot test a 'local' prefix
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const db = "/usr/share/zoneinfo";
    var tzinfo = try Tz.runtimeFromTzfile("Europe/Berlin", db, testing.allocator);
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tzinfo = tzinfo });
    try testing.expect(dt.__unix == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tzinfo != null);
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
}

test "embedded tzdata" {
    var tzinfo = try Tz.fromTzdata("Europe/Berlin", testing.allocator);
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tzinfo = tzinfo });
    try testing.expect(dt.__unix == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tzinfo != null);
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());

    const err = Tz.fromTzdata("Not/Defined", testing.allocator);
    try testing.expectError(TzError.TzUndefined, err);
}

test "invalid tzfile name" {
    const db = Tz.tzdb_prefix;
    //    log.warn("tz db: {s}", .{db});
    var err = Tz.runtimeFromTzfile("this is not a tzname", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
    err = Tz.runtimeFromTzfile("../test", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
    err = Tz.runtimeFromTzfile("*=!?:.", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
}

test "local tz" {
    var now = try Datetime.nowLocal(testing.allocator);
    defer _ = now.tzinfo.?.deinit();
    try testing.expect(now.tzinfo != null);
    try testing.expect(!std.mem.eql(u8, now.tzinfo.?.name(), ""));
    try testing.expect(!std.mem.eql(u8, now.tzinfo.?.abbreviation(), ""));
    //log.warn("{s}, {s}, {s}", .{ now, now.tzinfo.?.name(), now.tzinfo.?.abbreviation() });
}

test "DST transitions" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    var dt_std = try Datetime.fromUnix(1679792399, Duration.Resolution.second, tzinfo);
    var dt_dst = try Datetime.fromUnix(1679792400, Duration.Resolution.second, tzinfo);
    try testing.expect(!dt_std.tzinfo.?.tzOffset.?.is_dst);
    try testing.expect(dt_dst.tzinfo.?.tzOffset.?.is_dst);

    var s = std.ArrayList(u8).init(testing.allocator);
    try str.formatToString(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try testing.expectEqualStrings("2023-03-26T01:59:59+01:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(testing.allocator);
    try str.formatToString(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try testing.expectEqualStrings("2023-03-26T03:00:00+02:00", s.items);
    s.deinit();

    // DST on --> DST off (duplicate datetime), 2023-10-29
    dt_dst = try Datetime.fromUnix(1698541199, Duration.Resolution.second, tzinfo);
    dt_std = try Datetime.fromUnix(1698541200, Duration.Resolution.second, tzinfo);
    try testing.expect(!dt_std.tzinfo.?.tzOffset.?.is_dst);
    try testing.expect(dt_dst.tzinfo.?.tzOffset.?.is_dst);

    s = std.ArrayList(u8).init(testing.allocator);
    try str.formatToString(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try testing.expectEqualStrings("2023-10-29T02:59:59+02:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(testing.allocator);
    try str.formatToString(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try testing.expectEqualStrings("2023-10-29T02:00:00+01:00", s.items);
    s.deinit();
}

test "wall diff vs. abs diff" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    const dt_std = try Datetime.fromUnix(
        1679792399000000001,
        Duration.Resolution.nanosecond,
        tzinfo,
    );
    const dt_dst = try Datetime.fromUnix(
        1679792400000000002,
        Duration.Resolution.nanosecond,
        tzinfo,
    );
    try testing.expect(!dt_std.tzinfo.?.tzOffset.?.is_dst);
    try testing.expect(dt_dst.tzinfo.?.tzOffset.?.is_dst);

    const diff_abs = dt_std.diff(dt_dst); // just 1 sec and 1 nanosec
    const diff_wall = try dt_std.diffWall(dt_dst); // 1 hour, 1 sec and 1 nanosec
    try testing.expectEqual(
        @as(i128, -1000000001),
        diff_abs.toTimespanMultiple(Duration.Timespan.nanosecond),
    );
    try testing.expectEqual(
        @as(i128, -3601000000001),
        diff_wall.toTimespanMultiple(Duration.Timespan.nanosecond),
    );
}

test "tz has name and abbreviation" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 2, .tzinfo = tzinfo });
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 8, .tzinfo = tzinfo });
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CEST", dt.tzinfo.?.abbreviation());

    dt = try Datetime.fromUnix(1672527600, Duration.Resolution.second, tzinfo);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());

    dt = try Datetime.fromUnix(1690840800, Duration.Resolution.second, tzinfo);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CEST", dt.tzinfo.?.abbreviation());
}

test "longest tz name" {
    var tzinfo = try Tz.fromTzfile("America/Argentina/ComodRivadavia", testing.allocator);
    defer _ = tzinfo.deinit();
    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 2, .tzinfo = tzinfo });
    try testing.expectEqualStrings("America/Argentina/ComodRivadavia", dt.tzinfo.?.name());
}

test "early LMT, late CET" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1880, .tzinfo = tzinfo });
    try testing.expectEqualStrings("LMT", dt.tzinfo.?.abbreviation());

    dt = try Datetime.fromFields(.{ .year = 2039, .month = 8, .tzinfo = tzinfo });
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());
}

test "tz name and abbr correct after localize" {
    var tz_ny = try Tz.fromTzfile("America/New_York", testing.allocator);
    defer _ = tz_ny.deinit();

    var now_local: Datetime = Datetime.now(tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);

    now_local = Datetime.now(null);
    now_local = try now_local.tzLocalize(tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);

    const t = std.time.nanoTimestamp();
    now_local = try Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);

    const t2 = std.time.timestamp();
    now_local = try Datetime.fromUnix(t2, Duration.Resolution.second, tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);

    const t3: i32 = 0;
    now_local = try Datetime.fromUnix(t3, Duration.Resolution.second, tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);
    try testing.expectEqualStrings("EST", now_local.tzinfo.?.abbreviation());

    const t4: i32 = 1690840800;
    now_local = try Datetime.fromUnix(t4, Duration.Resolution.second, tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzinfo.?.name());
    try testing.expect(now_local.tzinfo.?.abbreviation().len > 0);
    try testing.expectEqualStrings("EDT", now_local.tzinfo.?.abbreviation());
}

test "tz name and abbr correct after conversion" {
    var tz_berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_berlin.deinit();
    var tz_denver = try Tz.fromTzfile("America/Denver", testing.allocator);
    defer _ = tz_denver.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .tzinfo = tz_berlin });
    var converted: Datetime = try dt.tzConvert(tz_denver);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CET", dt.tzinfo.?.abbreviation());
    try testing.expectEqualStrings("America/Denver", converted.tzinfo.?.name());
    try testing.expectEqualStrings("MST", converted.tzinfo.?.abbreviation());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 8, .tzinfo = tz_berlin });
    converted = try dt.tzConvert(tz_denver);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzinfo.?.name());
    try testing.expectEqualStrings("CEST", dt.tzinfo.?.abbreviation());
    try testing.expectEqualStrings("America/Denver", converted.tzinfo.?.name());
    try testing.expectEqualStrings("MDT", converted.tzinfo.?.abbreviation());
}

test "non-existent datetime" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try testing.expectError(ZdtError.NonexistentDatetime, dt);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/Denver", testing.allocator);
    dt = Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try testing.expectError(ZdtError.NonexistentDatetime, dt);
}

test "ambiguous datetime" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try testing.expectError(ZdtError.AmbiguousDatetime, dt);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/Denver", testing.allocator);
    dt = Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try testing.expectError(ZdtError.AmbiguousDatetime, dt);
}

test "ambiguous datetime / DST fold" {
    var tz_berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_berlin.deinit();

    // DST on, offset 7200 s
    var dt_early = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 0, .tzinfo = tz_berlin });
    // DST off, offset 3600 s
    var dt_late = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 1, .tzinfo = tz_berlin });
    try testing.expectEqual(7200, dt_early.tzinfo.?.tzOffset.?.seconds_east);
    try testing.expectEqual(3600, dt_late.tzinfo.?.tzOffset.?.seconds_east);

    var tz_mountain = try Tz.fromTzfile("America/Denver", testing.allocator);
    defer tz_mountain.deinit();
    dt_early = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .dst_fold = 0, .tzinfo = tz_mountain });
    dt_late = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .dst_fold = 1, .tzinfo = tz_mountain });
    try testing.expectEqual(-21600, dt_early.tzinfo.?.tzOffset.?.seconds_east);
    try testing.expectEqual(-25200, dt_late.tzinfo.?.tzOffset.?.seconds_east);
}

test "tz without transitions at UTC+9" {
    var tzinfo = try Tz.fromTzfile("Asia/Tokyo", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
}

test "make datetime aware" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try Datetime.fromUnix(0, Duration.Resolution.second, null);
    try testing.expect(dt_naive.tzinfo == null);

    var dt_aware = try dt_naive.tzLocalize(tzinfo);
    try testing.expect(dt_aware.tzinfo != null);
    try testing.expect(dt_aware.__unix != dt_naive.__unix);
    try testing.expect(dt_aware.__unix == -3600);
    try testing.expect(dt_aware.year == dt_naive.year);
    try testing.expect(dt_aware.day == dt_naive.day);
    try testing.expect(dt_aware.hour == dt_naive.hour);

    const naive_again = try dt_aware.tzLocalize(null);
    try testing.expect(std.meta.eql(dt_naive, naive_again));
}

test "replace tz in aware datetime" {
    var tz_Berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_Berlin.deinit();

    const dt_utc = Datetime.epoch;
    const dt_berlin = try dt_utc.tzLocalize(tz_Berlin);

    try testing.expect(dt_berlin.tzinfo != null);
    try testing.expect(dt_berlin.__unix != dt_utc.__unix);
    try testing.expect(dt_berlin.__unix == -3600);
    try testing.expect(dt_berlin.year == dt_utc.year);
    try testing.expect(dt_berlin.day == dt_utc.day);
    try testing.expect(dt_berlin.hour == dt_utc.hour);
}

test "replace tz fails for non-existent datetime in target tz" {
    var tz_Berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_Berlin.deinit();

    const dt_utc = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = Tz.UTC });
    const err = dt_utc.tzLocalize(tz_Berlin);

    try testing.expectError(ZdtError.NonexistentDatetime, err);
}

test "convert time zone" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try Datetime.fromUnix(42, Duration.Resolution.nanosecond, null);
    const err = dt_naive.tzConvert(tzinfo);
    try testing.expectError(ZdtError.TzUndefined, err);

    const dt_Berlin = try Datetime.fromUnix(42, Duration.Resolution.nanosecond, tzinfo);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/New_York", testing.allocator);
    const dt_NY = try dt_Berlin.tzConvert(tzinfo);

    try testing.expect(dt_Berlin.__unix == dt_NY.__unix);
    try testing.expect(dt_Berlin.nanosecond == dt_NY.nanosecond);
    try testing.expect(dt_Berlin.hour != dt_NY.hour);
}

test "make TZ with convenience func" {
    const off = try Tz.fromOffset(42, "hello_world");
    try testing.expect(off.tzFile == null);
    try testing.expect(off.tzPosix == null);
    try testing.expect(off.tzOffset != null);

    var tzinfo = try Tz.fromTzfile("Asia/Kolkata", testing.allocator);
    defer _ = tzinfo.deinit();
    try testing.expect(tzinfo.tzFile != null);
    try testing.expect(tzinfo.tzPosix == null);
    try testing.expect(tzinfo.tzOffset == null);
}

test "floor to date changes UTC offset" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 5, .tzinfo = tzinfo });
    var dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(@as(u8, 0), dt_floored.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(i32, 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    try testing.expectEqual(@as(i32, 7200), dt_floored.tzinfo.?.tzOffset.?.seconds_east);

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 3, .tzinfo = tzinfo });
    dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(@as(u8, 0), dt_floored.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(i32, 7200), dt.tzinfo.?.tzOffset.?.seconds_east);
    try testing.expectEqual(@as(i32, 3600), dt_floored.tzinfo.?.tzOffset.?.seconds_east);
}

test "load a lot of zones" {
    var tz_a = Tz{};
    defer tz_a.deinit();
    var dt_a = Datetime{};
    const zones = [_][]const u8{
        "America/La_Paz",
        "Pacific/Saipan",
        "Asia/Muscat",
        "Pacific/Gambier",
        "Asia/Kolkata",
        "Asia/Anadyr",
        "Asia/Baku",
        "Africa/Maseru",
        "Europe/Brussels",
        "Indian/Mahe",
        "Africa/Abidjan",
        "Etc/GMT-1",
        "America/Guyana",
        "Mexico/BajaNorte",
        "Antarctica/Davis",
        "Europe/Malta",
        "Africa/Libreville",
        "Singapore",
        "America/Aruba",
        "Australia/Broken_Hill",
        "Asia/Yekaterinburg",
        "Europe/Sarajevo",
        "Europe/Warsaw",
        "Antarctica/Mawson",
        "Europe/Zurich",
        "Atlantic/Reykjavik",
        "Africa/Porto-Novo",
        "Asia/Vientiane",
        "America/Argentina/San_Juan",
        "Etc/GMT+3",
        "America/Maceio",
        "America/Manaus",
        "Poland",
        "US/Central",
        "Pacific/Auckland",
        "GMT0",
        "Asia/Kashgar",
        "Asia/Barnaul",
        "Etc/GMT-10",
        "Asia/Phnom_Penh",
        "America/Metlakatla",
        "America/Nome",
        "America/Anguilla",
        "Iceland",
        "America/Whitehorse",
        "Asia/Kuwait",
        "Asia/Almaty",
        "America/Indiana/Winamac",
        "America/Eirunepe",
        "Africa/Asmara",
        "Etc/GMT0",
        "Asia/Ujung_Pandang",
        "Jamaica",
        "Asia/Famagusta",
        "Asia/Jerusalem",
        "Australia/Yancowinna",
        "Brazil/DeNoronha",
        "America/St_Thomas",
        "EST",
        "America/Jujuy",
        "Pacific/Tongatapu",
        "America/Araguaina",
        "Australia/Queensland",
        "Pacific/Marquesas",
        "Europe/Mariehamn",
        "Europe/Belfast",
        "Africa/Malabo",
        "Europe/London",
        "Asia/Dacca",
        "America/Rainy_River",
        "US/Arizona",
        "America/Jamaica",
        "Asia/Pontianak",
        "Canada/Mountain",
        "America/Cordoba",
        "CST6CDT",
        "America/Tegucigalpa",
        "America/Pangnirtung",
        "GMT",
        "Atlantic/Canary",
        "America/Panama",
        "Africa/Mbabane",
        "Europe/Zagreb",
        "America/Coral_Harbour",
        "Australia/South",
        "Eire",
        "America/Chihuahua",
        "Africa/Johannesburg",
        "Asia/Aden",
        "Asia/Aqtobe",
        "America/St_Vincent",
        "Australia/Hobart",
        "Australia/Melbourne",
        "Asia/Saigon",
        "Europe/Copenhagen",
        "GMT+0",
        "America/Montserrat",
        "America/Fort_Wayne",
        "America/North_Dakota/Center",
        "America/Cuiaba",
        "Asia/Chita",
        "Europe/Simferopol",
        "Pacific/Wake",
        "Asia/Aqtau",
        "America/Recife",
        "Africa/Banjul",
        "Africa/Nairobi",
        "Asia/Yangon",
        "Asia/Novokuznetsk",
        "Asia/Ashgabat",
        "America/Belem",
        "PRC",
        "America/Cayenne",
        "Africa/Harare",
        "Asia/Magadan",
        "Atlantic/Faroe",
        "America/Atikokan",
        "Africa/Timbuktu",
        "Australia/Lord_Howe",
        "Europe/Rome",
        "Europe/Bucharest",
        "Africa/Tripoli",
        "Pacific/Honolulu",
        "America/Thule",
        "America/Merida",
        "Asia/Krasnoyarsk",
        "Atlantic/St_Helena",
        "America/Guayaquil",
        "Etc/GMT+9",
        "Asia/Irkutsk",
        "US/Hawaii",
        "America/Argentina/Ushuaia",
        "Europe/Kirov",
        "Asia/Kathmandu",
        "Europe/Luxembourg",
        "Africa/Ouagadougou",
        "America/Argentina/Catamarca",
        "Africa/Cairo",
        "America/Porto_Acre",
        "Europe/San_Marino",
        "Asia/Ho_Chi_Minh",
        "America/Cambridge_Bay",
        "Chile/Continental",
        "Pacific/Pago_Pago",
        "America/Fortaleza",
        "America/Port-au-Prince",
        "Africa/Gaborone",
        "Africa/Freetown",
        "America/Kralendijk",
        "America/Argentina/ComodRivadavia",
        "Atlantic/South_Georgia",
        "Europe/Bratislava",
        "Cuba",
        "Australia/Victoria",
        "Pacific/Apia",
        "NZ",
        "Pacific/Pohnpei",
        "America/North_Dakota/Beulah",
        "Australia/North",
        "US/Eastern",
        "NZ-CHAT",
        "Indian/Kerguelen",
        "America/Rankin_Inlet",
        "America/Creston",
        "Asia/Tbilisi",
        "America/Marigot",
        "Etc/GMT-2",
        "America/Winnipeg",
        "Europe/Oslo",
        "America/Tijuana",
        "Chile/EasterIsland",
        "America/Sitka",
        "America/Curacao",
        "Asia/Tokyo",
        "Brazil/East",
        "Asia/Dubai",
        "Africa/Juba",
        "Asia/Tehran",
        "America/Halifax",
        "Australia/Lindeman",
        "America/Blanc-Sablon",
        "Europe/Budapest",
        "Asia/Jayapura",
        "Pacific/Palau",
        "Hongkong",
        "America/Atka",
        "Asia/Atyrau",
        "Africa/Djibouti",
        "Atlantic/Stanley",
        "America/Santarem",
        "Antarctica/Casey",
        "America/Dominica",
        "Africa/Bangui",
        "Asia/Novosibirsk",
        "Europe/Guernsey",
        "Pacific/Yap",
        "Australia/Tasmania",
        "Africa/Lagos",
        "Etc/GMT-13",
        "Etc/GMT-9",
        "Canada/Central",
        "America/Ojinaga",
        "America/Costa_Rica",
        "Asia/Dhaka",
        "Asia/Amman",
        "Africa/Monrovia",
        "Asia/Qyzylorda",
        "Europe/Skopje",
        "Asia/Nicosia",
        "America/Ciudad_Juarez",
        "Israel",
        "Etc/GMT+5",
        "Africa/Kampala",
        "Asia/Calcutta",
        "Europe/Volgograd",
        "Asia/Beirut",
        "Australia/Perth",
        "America/Guatemala",
        "America/Indiana/Petersburg",
        "America/Paramaribo",
        "Asia/Baghdad",
        "Australia/Currie",
        "Pacific/Truk",
        "America/Porto_Velho",
        "Indian/Comoro",
        "Pacific/Midway",
        "Pacific/Easter",
        "Canada/Yukon",
        "America/Indiana/Vincennes",
        "Etc/GMT-5",
        "America/Punta_Arenas",
        "Mexico/BajaSur",
        "America/Ensenada",
        "America/Inuvik",
        "Australia/ACT",
        "EET",
        "America/Los_Angeles",
        "Asia/Srednekolymsk",
        "Zulu",
        "Europe/Jersey",
        "Europe/Zaporozhye",
        "America/Cancun",
        "Pacific/Tahiti",
        "Europe/Istanbul",
        "Africa/Maputo",
        "Asia/Kabul",
        "Europe/Busingen",
        "America/Detroit",
        "America/Argentina/Tucuman",
        "Asia/Qatar",
        "Europe/Saratov",
        "Europe/Belgrade",
        "America/Dawson",
        "Asia/Ulan_Bator",
        "Indian/Christmas",
        "Europe/Ulyanovsk",
        "Pacific/Guadalcanal",
        "Canada/Atlantic",
        "Africa/Ceuta",
        "Etc/GMT-4",
        "America/Antigua",
        "Antarctica/Vostok",
        "America/Mazatlan",
        "US/Michigan",
        "Australia/Eucla",
        "Africa/Addis_Ababa",
        "Africa/Lubumbashi",
        "Asia/Thimphu",
        "Antarctica/Syowa",
        "Europe/Ljubljana",
        "Asia/Urumqi",
        "America/St_Johns",
        "America/Godthab",
        "Europe/Riga",
        "Asia/Katmandu",
        "Pacific/Funafuti",
        "America/Moncton",
        "ROK",
        "Pacific/Chuuk",
        "Factory",
        "America/Swift_Current",
        "America/Goose_Bay",
        "Europe/Vatican",
        "America/Tortola",
        "America/Argentina/Cordoba",
        "America/Boa_Vista",
        "Africa/Sao_Tome",
        "Pacific/Nauru",
        "America/Argentina/Buenos_Aires",
        "Canada/Newfoundland",
        "Antarctica/McMurdo",
        "PST8PDT",
        "Australia/Brisbane",
        "Europe/Paris",
        "Africa/Khartoum",
        "Etc/GMT-3",
        "America/Catamarca",
        "Europe/Uzhgorod",
        "Pacific/Bougainville",
        "America/Noronha",
        "America/Guadeloupe",
        "Europe/Lisbon",
        "America/Kentucky/Monticello",
        "Asia/Harbin",
        "Europe/Kiev",
        "America/Cayman",
        "Pacific/Kanton",
        "America/Martinique",
        "America/Santa_Isabel",
        "America/Lower_Princes",
        "Pacific/Port_Moresby",
        "America/Thunder_Bay",
        "Asia/Dili",
        "Iran",
        "America/Hermosillo",
        "Europe/Samara",
        "America/Matamoros",
        "America/Bogota",
        "Europe/Tiraspol",
        "Atlantic/Jan_Mayen",
        "Africa/Accra",
        "America/Boise",
        "Libya",
        "Africa/Bissau",
        "WET",
        "Asia/Bangkok",
        "America/Puerto_Rico",
        "Asia/Pyongyang",
        "Etc/GMT-0",
        "Africa/Dar_es_Salaam",
        "America/Argentina/Salta",
        "Etc/GMT-6",
        "America/Shiprock",
        "America/Anchorage",
        "Atlantic/Azores",
        "America/St_Lucia",
        "America/Grenada",
        "Asia/Tomsk",
        "Asia/Colombo",
        "Europe/Athens",
        "America/Rosario",
        "Australia/Sydney",
        "Europe/Tallinn",
        "Asia/Singapore",
        "Europe/Astrakhan",
        "Africa/Windhoek",
        "Europe/Podgorica",
        "Africa/Douala",
        "Asia/Gaza",
        "Canada/Pacific",
        "Pacific/Rarotonga",
        "America/Rio_Branco",
        "Asia/Bahrain",
        "Pacific/Norfolk",
        "Pacific/Noumea",
        "Europe/Kaliningrad",
        "Greenwich",
        "US/Samoa",
        "Africa/Bujumbura",
        "America/Dawson_Creek",
        "Pacific/Niue",
        "America/Argentina/La_Rioja",
        "America/Glace_Bay",
        "Atlantic/Bermuda",
        "Asia/Hovd",
        "America/Campo_Grande",
        "Asia/Istanbul",
        "Asia/Tel_Aviv",
        "Australia/Adelaide",
        "America/Danmarkshavn",
        "Asia/Ulaanbaatar",
        "Pacific/Pitcairn",
        "Pacific/Guam",
        "Pacific/Samoa",
        "Asia/Qostanay",
        "America/Nipigon",
        "Africa/Nouakchott",
        "Asia/Bishkek",
        "GB",
        "Etc/GMT-7",
        "America/Yellowknife",
        "Indian/Antananarivo",
        "America/Belize",
        "Asia/Karachi",
        "Asia/Taipei",
        "Africa/Brazzaville",
        "Asia/Choibalsan",
        "GB-Eire",
        "Etc/GMT+0",
        "Asia/Sakhalin",
        "America/Mendoza",
        "Africa/Lusaka",
        "Canada/Saskatchewan",
        "America/St_Kitts",
        "Indian/Mayotte",
        "Europe/Isle_of_Man",
        "Indian/Cocos",
        "America/Grand_Turk",
        "W-SU",
        "America/Kentucky/Louisville",
        "Africa/Kigali",
        "America/Vancouver",
        "Europe/Prague",
        "Etc/GMT+6",
        "Africa/Blantyre",
        "Asia/Chungking",
        "Asia/Oral",
        "Pacific/Fiji",
        "Indian/Maldives",
        "Australia/LHI",
        "Australia/NSW",
        "US/Mountain",
        "Pacific/Chatham",
        "Africa/Kinshasa",
        "America/North_Dakota/New_Salem",
        "Europe/Nicosia",
        "Asia/Riyadh",
        "Pacific/Enderbury",
        "Africa/Casablanca",
        "Etc/UCT",
        "US/Indiana-Starke",
        "Universal",
        "Pacific/Wallis",
        "MST7MDT",
        "Asia/Khandyga",
        "Europe/Dublin",
        "America/Adak",
        "America/Monterrey",
        "Asia/Chongqing",
        "Europe/Minsk",
        "Antarctica/Macquarie",
        "Asia/Omsk",
        "America/Bahia",
        "Asia/Rangoon",
        "US/Aleutian",
        "Etc/GMT+12",
        "America/Indiana/Marengo",
        "Africa/Tunis",
        "Europe/Vaduz",
        "Portugal",
        "HST",
        "America/Santo_Domingo",
        "Pacific/Kosrae",
        "Etc/GMT+7",
        "Etc/GMT-12",
        "Asia/Dushanbe",
        "America/Indiana/Knox",
        "Pacific/Kiritimati",
        "America/Louisville",
        "America/Argentina/Mendoza",
        "Europe/Chisinau",
        "Etc/GMT+1",
        "Africa/Algiers",
        "Asia/Kuala_Lumpur",
        "Asia/Hebron",
        "America/Phoenix",
        "America/Caracas",
        "Asia/Manila",
        "Asia/Jakarta",
        "America/Edmonton",
        "Africa/Bamako",
        "Pacific/Tarawa",
        "America/Fort_Nelson",
        "America/St_Barthelemy",
        "Australia/Darwin",
        "Asia/Yerevan",
        "Asia/Yakutsk",
        "Europe/Tirane",
        "Navajo",
        "Etc/GMT+4",
        "Africa/Niamey",
        "Europe/Sofia",
        "Pacific/Fakaofo",
        "Antarctica/Palmer",
        "Asia/Thimbu",
        "Europe/Madrid",
        "US/East-Indiana",
        "Africa/Dakar",
        "Etc/Zulu",
        "Pacific/Kwajalein",
        "America/Argentina/Rio_Gallegos",
        "Etc/GMT-8",
        "GMT-0",
        "America/Nassau",
        "Europe/Berlin",
        "Europe/Vilnius",
        "Brazil/West",
        "Etc/GMT+11",
        "America/Menominee",
        "Etc/UTC",
        "America/Scoresbysund",
        "Pacific/Johnston",
        "America/Sao_Paulo",
        "America/Port_of_Spain",
        "Kwajalein",
        "America/Buenos_Aires",
        "Indian/Reunion",
        "Asia/Makassar",
        "America/Toronto",
        "Antarctica/DumontDUrville",
        "America/Indianapolis",
        "Asia/Brunei",
        "Asia/Kamchatka",
        "Etc/GMT+10",
        "CET",
        "Atlantic/Faeroe",
        "Atlantic/Cape_Verde",
        "Pacific/Galapagos",
        "US/Alaska",
        "Pacific/Ponape",
        "America/Resolute",
        "Turkey",
        "Europe/Moscow",
        "America/El_Salvador",
        "Antarctica/South_Pole",
        "Asia/Vladivostok",
        "America/Asuncion",
        "Asia/Samarkand",
        "Indian/Chagos",
        "Atlantic/Madeira",
        "Europe/Kyiv",
        "Asia/Macao",
        "MET",
        "EST5EDT",
        "Europe/Stockholm",
        "Africa/Asmera",
        "Japan",
        "America/Bahia_Banderas",
        "Asia/Damascus",
        "Europe/Helsinki",
        "America/Denver",
        "America/Iqaluit",
        "America/Managua",
        "Pacific/Majuro",
        "Etc/GMT+8",
        "America/Indiana/Tell_City",
        "America/Lima",
        "America/Nuuk",
        "Etc/GMT-14",
        "Africa/El_Aaiun",
        "America/Miquelon",
        "Africa/Ndjamena",
        "America/Indiana/Vevay",
        "Etc/GMT-11",
        "US/Pacific",
        "Asia/Seoul",
        "America/Barbados",
        "America/Regina",
        "UTC",
        "Etc/GMT+2",
        "Africa/Luanda",
        "America/Montreal",
        "Africa/Mogadishu",
        "America/Chicago",
        "Antarctica/Troll",
        "Egypt",
        "Asia/Ust-Nera",
        "ROC",
        "Pacific/Efate",
        "Asia/Macau",
        "Asia/Shanghai",
        "America/Mexico_City",
        "Etc/Greenwich",
        "America/Yakutat",
        "America/Virgin",
        "Africa/Conakry",
        "Etc/Universal",
        "Australia/Canberra",
        "MST",
        "Asia/Kuching",
        "America/Montevideo",
        "America/Indiana/Indianapolis",
        "Asia/Tashkent",
        "America/Havana",
        "Canada/Eastern",
        "Europe/Andorra",
        "America/Argentina/San_Luis",
        "Europe/Gibraltar",
        "Europe/Amsterdam",
        "Etc/GMT",
        "Europe/Monaco",
        "America/Knox_IN",
        "America/New_York",
        "Indian/Mauritius",
        "America/Juneau",
        "UCT",
        "Asia/Hong_Kong",
        "America/Santiago",
        "Europe/Vienna",
        "Brazil/Acre",
        "Mexico/General",
        "Australia/West",
        "America/Argentina/Jujuy",
        "Africa/Lome",
        "Antarctica/Rothera",
        "Asia/Ashkhabad",
        "Arctic/Longyearbyen",
    };

    inline for (zones) |zone| {
        tz_a = try Tz.fromTzfile(zone, testing.allocator);
        dt_a = try Datetime.fromUnix(1, Duration.Resolution.second, tz_a);
        try testing.expectEqualStrings(zone, dt_a.tzinfo.?.name());
        try testing.expect(dt_a.tzinfo.?.tzFile != null);
        try testing.expect(dt_a.tzinfo.?.tzOffset != null);
        tz_a.deinit();

        tz_a = try Tz.fromTzdata(zone, testing.allocator);
        dt_a = try Datetime.fromUnix(1, Duration.Resolution.second, tz_a);
        try testing.expectEqualStrings(zone, dt_a.tzinfo.?.name());
        try testing.expect(dt_a.tzinfo.?.tzFile != null);
        try testing.expect(dt_a.tzinfo.?.tzOffset != null);
        tz_a.deinit();
    }
}

// the following test is auto-generated. do not edit this line and below.

test "conversion between random time zones" {
    var tz_a = Tz{};
    var tz_b = Tz{};
    defer tz_a.deinit();
    defer tz_b.deinit();
    var dt_a = Datetime{};
    var dt_b = Datetime{};
    var dt_c = Datetime{};
    var s_b = std.ArrayList(u8).init(testing.allocator);
    var s_c = std.ArrayList(u8).init(testing.allocator);
    defer s_b.deinit();
    defer s_c.deinit();

    tz_a = try Tz.fromTzfile("America/Noronha", testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Volgograd", testing.allocator);
    dt_a = try Datetime.fromUnix(-1667178601, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1391111626, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1925-12-02T02:06:14-02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1917-03-04T01:47:39+02:57:40", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Nicosia", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Aruba", testing.allocator);
    dt_a = try Datetime.fromUnix(-1139903279, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-422363402, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1956-08-13T14:49:58+02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1933-11-17T12:12:01-04:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Australia/NSW", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Ulan_Bator", testing.allocator);
    dt_a = try Datetime.fromUnix(202463633, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(1669207832, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("2022-11-23T23:50:32+11:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1976-06-01T14:53:53+07:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Halifax", testing.allocator);
    tz_b = try Tz.fromTzfile("Pacific/Efate", testing.allocator);
    dt_a = try Datetime.fromUnix(576423124, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(551161374, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1987-06-20T01:22:54-03:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1988-04-08T00:32:04+11:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Argentina/Ushuaia", testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Saratov", testing.allocator);
    dt_a = try Datetime.fromUnix(-1682852184, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(1349104459, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("2012-10-01T12:14:19-03:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1916-09-03T16:07:54+03:04:18", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Pacific/Tongatapu", testing.allocator);
    tz_b = try Tz.fromTzfile("Hongkong", testing.allocator);
    dt_a = try Datetime.fromUnix(1916129356, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1123806767, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1934-05-23T11:46:25+12:19:12", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2030-09-20T18:09:16+08:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/Mariehamn", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Pyongyang", testing.allocator);
    dt_a = try Datetime.fromUnix(-1922676780, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1247650419, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1930-06-19T16:26:21+02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1909-01-28T03:37:00+08:30", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/St_Lucia", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Eirunepe", testing.allocator);
    dt_a = try Datetime.fromUnix(-767770882, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(1363693749, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("2013-03-19T07:49:09-04:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1945-09-02T13:18:38-05:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Argentina/Mendoza", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Godthab", testing.allocator);
    dt_a = try Datetime.fromUnix(1653739248, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(287718809, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1979-02-12T22:53:29-03:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2022-05-28T10:00:48-02:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Canada/Pacific", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Goose_Bay", testing.allocator);
    dt_a = try Datetime.fromUnix(666154488, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-452535075, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1955-08-30T00:48:45-07:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1991-02-09T22:54:48-04:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Pacific/Chatham", testing.allocator);
    tz_b = try Tz.fromTzfile("Pacific/Guam", testing.allocator);
    dt_a = try Datetime.fromUnix(-1508560609, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-106361335, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1966-08-19T11:56:05+12:45", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1922-03-14T05:23:11+10:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("EST", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Shiprock", testing.allocator);
    dt_a = try Datetime.fromUnix(1984454746, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(504113205, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1985-12-22T10:26:45-05:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2032-11-18T22:25:46-07:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Tripoli", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Tbilisi", testing.allocator);
    dt_a = try Datetime.fromUnix(-1319816614, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(1997132129, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("2033-04-15T00:55:29+02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1928-03-06T11:16:26+03:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/Copenhagen", testing.allocator);
    tz_b = try Tz.fromTzfile("Africa/Cairo", testing.allocator);
    dt_a = try Datetime.fromUnix(869986522, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1955947824, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1908-01-08T18:09:36+01:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1997-07-27T09:55:22+03:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Dar_es_Salaam", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Phnom_Penh", testing.allocator);
    dt_a = try Datetime.fromUnix(-483354134, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(763622303, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1994-03-14T08:18:23+03:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1954-09-07T21:57:46+07:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Porto_Velho", testing.allocator);
    tz_b = try Tz.fromTzfile("Pacific/Kosrae", testing.allocator);
    dt_a = try Datetime.fromUnix(101650878, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1665590578, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1917-03-22T03:57:02-04:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1973-03-23T00:21:18+12:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Amman", testing.allocator);
    tz_b = try Tz.fromTzfile("Atlantic/Faroe", testing.allocator);
    dt_a = try Datetime.fromUnix(-804636860, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-130203183, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1965-11-16T02:26:57+02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1944-07-03T01:45:40+00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Zulu", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Kuala_Lumpur", testing.allocator);
    dt_a = try Datetime.fromUnix(-301750972, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-678498351, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1948-07-02T00:14:09+00:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1960-06-09T19:47:08+07:30", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Rosario", testing.allocator);
    tz_b = try Tz.fromTzfile("CST6CDT", testing.allocator);
    dt_a = try Datetime.fromUnix(-946368248, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1786706330, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1913-05-20T08:24:22-04:16:48", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1940-01-05T09:55:52-06:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Bujumbura", testing.allocator);
    tz_b = try Tz.fromTzfile("Pacific/Kiritimati", testing.allocator);
    dt_a = try Datetime.fromUnix(1718888449, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1292830223, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1929-01-12T18:29:37+02:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2024-06-21T03:00:49+14:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Etc/GMT+10", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Nome", testing.allocator);
    dt_a = try Datetime.fromUnix(671659627, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-848311788, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1943-02-13T03:50:12-10:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1991-04-14T12:07:07-08:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Australia/Canberra", testing.allocator);
    tz_b = try Tz.fromTzfile("Etc/GMT+3", testing.allocator);
    dt_a = try Datetime.fromUnix(973474793, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-2118943269, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1902-11-09T14:38:51+10:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2000-11-05T22:39:53-03:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Australia/Currie", testing.allocator);
    tz_b = try Tz.fromTzfile("Africa/Nouakchott", testing.allocator);
    dt_a = try Datetime.fromUnix(1588404064, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(1647602753, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("2022-03-18T22:25:53+11:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("2020-05-02T07:21:04+00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Antarctica/Casey", testing.allocator);
    tz_b = try Tz.fromTzfile("America/Martinique", testing.allocator);
    dt_a = try Datetime.fromUnix(-736189940, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-729899108, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1946-11-15T02:14:52+00:00", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1946-09-03T02:47:40-04:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Riyadh", testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Kathmandu", testing.allocator);
    dt_a = try Datetime.fromUnix(451163746, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix(-1075050004, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatToString(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("1935-12-08T10:06:48+03:06:52", s_b.items);
    try str.formatToString(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("1984-04-19T00:45:46+05:30", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();
}
