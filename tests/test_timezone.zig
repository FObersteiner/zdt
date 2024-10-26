//! test timezone from a users's perspective (no internal functionality)

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const UTCoffset = zdt.UTCoffset;
const ZdtError = zdt.ZdtError;

const log = std.log.scoped(.test_timezone);

test "utc" {
    var utc = UTCoffset.UTC;
    try testing.expect(utc.seconds_east == 0);
    try testing.expectEqualStrings(utc.designation(), "UTC");

    var utc_now = Datetime.nowUTC();
    try testing.expectEqualStrings(utc_now.utc_offset.?.designation(), "UTC");

    try testing.expectEqualStrings(utc_now.tzName(), "UTC");
    try testing.expectEqualStrings(utc_now.tzAbbreviation(), "Z");
}

test "offset from seconds" {
    var off = try UTCoffset.fromSeconds(999, "hello world");
    try testing.expect(std.mem.eql(u8, off.designation(), "hello "));

    var err: zdt.ZdtError!zdt.UTCoffset = UTCoffset.fromSeconds(-99999, "invalid");
    try testing.expectError(ZdtError.InvalidOffset, err);
    err = UTCoffset.fromSeconds(99999, "invalid");
    try testing.expectError(ZdtError.InvalidOffset, err);

    off = try UTCoffset.fromSeconds(3600, "UTC+1");
    const dt = try Datetime.fromFields(.{ .year = 1970, .utc_offset = off });
    try testing.expect(dt.unix_sec == -3600);
    try testing.expect(dt.hour == 0);

    const dt_unix = try Datetime.fromUnix(0, Duration.Resolution.second, off, null);
    try testing.expect(dt_unix.unix_sec == 0);
    try testing.expect(dt_unix.hour == 1);

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    const string = "1970-01-01T00:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%:z";
    try dt.toString(directive, buf.writer());
    try testing.expectEqualStrings(string, buf.items);
}

test "mem error" {
    const allocator = testing.failing_allocator;
    const err = Tz.fromTzfile("UTC", allocator);
    try testing.expectError(ZdtError.TZifUnreadable, err);
}

test "tzfile tz manifests in Unix time" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tz = &tzinfo });
    try testing.expect(dt.unix_sec == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tz != null);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());

    tzinfo.deinit();
    try testing.expectEqualStrings("", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());
}

test "local tz db, from specified or default prefix" {
    // NOTE : Windows does not use the IANA db, so we cannot test a 'local' prefix
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const db = "/usr/share/zoneinfo";
    var tzinfo = try Tz.runtimeFromTzfile("Europe/Berlin", db, testing.allocator);
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tz = &tzinfo });
    try testing.expect(dt.unix_sec == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tz != null);
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
}

test "embedded tzdata" {
    var tzinfo = try Tz.fromTzdata("Europe/Berlin", testing.allocator);
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tz = &tzinfo });
    try testing.expect(dt.unix_sec == -3600);
    try testing.expect(dt.hour == 0);
    try testing.expect(dt.nanosecond == 1);
    try testing.expect(dt.tz != null);
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());

    const err = Tz.fromTzdata("Not/Defined", testing.allocator);
    try testing.expectError(ZdtError.TzUndefined, err);
}

test "invalid tzfile name" {
    const db = Tz.tzdb_prefix;
    // log.warn("tz db: {s}", .{db});
    var err = Tz.runtimeFromTzfile("this is not a tzname", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
    err = Tz.runtimeFromTzfile("../test", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
    err = Tz.runtimeFromTzfile("*=!?:.", db, testing.allocator);
    try testing.expectError(ZdtError.InvalidIdentifier, err);
}

test "local tz" {
    var tzinfo = try Tz.tzLocal(testing.allocator);
    defer tzinfo.deinit();
    var now = try Datetime.now(&tzinfo);

    try testing.expect(now.tz != null);
    try testing.expect(!std.mem.eql(u8, now.tzName(), ""));
    try testing.expect(!std.mem.eql(u8, now.tzAbbreviation(), ""));
    // log.warn("{s}, {s}, {s}", .{ now, now.tzinfo.?.name(), now.tzinfo.?.abbreviation() });
}

test "DST transitions" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    var dt_std = try Datetime.fromUnix(1679792399, Duration.Resolution.second, null, &tzinfo);
    var dt_dst = try Datetime.fromUnix(1679792400, Duration.Resolution.second, null, &tzinfo);
    try testing.expect(!dt_std.utc_offset.?.is_dst);
    try testing.expect(dt_dst.utc_offset.?.is_dst);

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();
    try dt_std.toString("%Y-%m-%dT%H:%M:%S%:z", buf.writer());
    try testing.expectEqualStrings("2023-03-26T01:59:59+01:00", buf.items);
    buf.clearAndFree();

    try dt_dst.toString("%Y-%m-%dT%H:%M:%S%:z", buf.writer());
    try testing.expectEqualStrings("2023-03-26T03:00:00+02:00", buf.items);
    buf.clearAndFree();

    // DST on --> DST off (duplicate datetime), 2023-10-29
    dt_dst = try Datetime.fromUnix(1698541199, Duration.Resolution.second, null, &tzinfo);
    dt_std = try Datetime.fromUnix(1698541200, Duration.Resolution.second, null, &tzinfo);
    try testing.expect(dt_dst.utc_offset.?.is_dst);
    try testing.expect(!dt_std.utc_offset.?.is_dst);

    try dt_dst.toString("%Y-%m-%dT%H:%M:%S%:z", buf.writer());
    try testing.expectEqualStrings("2023-10-29T02:59:59+02:00", buf.items);
    buf.clearAndFree();

    try dt_std.toString("%Y-%m-%dT%H:%M:%S%:z", buf.writer());
    try testing.expectEqualStrings("2023-10-29T02:00:00+01:00", buf.items);
    buf.clearAndFree();
}

test "wall diff vs. abs diff" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    const dt_std = try Datetime.fromUnix(
        1679792399000000001,
        Duration.Resolution.nanosecond,
        null,
        &tzinfo,
    );
    const dt_dst = try Datetime.fromUnix(
        1679792400000000002,
        Duration.Resolution.nanosecond,
        null,
        &tzinfo,
    );
    try testing.expect(!dt_std.utc_offset.?.is_dst);
    try testing.expect(dt_dst.utc_offset.?.is_dst);

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

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 2, .tz = &tzinfo });
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 8, .tz = &tzinfo });
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CEST", dt.tzAbbreviation());

    dt = try Datetime.fromUnix(1672527600, Duration.Resolution.second, null, &tzinfo);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());

    dt = try Datetime.fromUnix(1690840800, Duration.Resolution.second, null, &tzinfo);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CEST", dt.tzAbbreviation());
}

test "longest tz name" {
    var tzinfo = try Tz.fromTzfile("America/Argentina/ComodRivadavia", testing.allocator);
    defer _ = tzinfo.deinit();
    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 2, .tz = &tzinfo });
    try testing.expectEqualStrings("America/Argentina/ComodRivadavia", dt.tzName());
}

test "early LMT, late CET" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 1880, .tz = &tzinfo });
    try testing.expectEqualStrings("LMT", dt.tzAbbreviation());

    // NOTE: this might fail in 10 years from 2024...
    dt = try Datetime.fromFields(.{ .year = 2039, .month = 8, .tz = &tzinfo });
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());
}

test "tz name and abbr correct after localize" {
    var tz_ny = try Tz.fromTzfile("America/New_York", testing.allocator);
    defer _ = tz_ny.deinit();

    var now_local: Datetime = try Datetime.now(&tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expect(now_local.tzAbbreviation().len > 0);

    now_local = try Datetime.now(null);
    now_local = try now_local.tzLocalize(&tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expect(now_local.tzAbbreviation().len > 0);

    const t = std.time.nanoTimestamp();
    now_local = try Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, null, &tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expect(now_local.tzAbbreviation().len > 0);

    const t2 = std.time.timestamp();
    now_local = try Datetime.fromUnix(t2, Duration.Resolution.second, null, &tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expect(now_local.tzAbbreviation().len > 0);

    const t3: i32 = 0;
    now_local = try Datetime.fromUnix(t3, Duration.Resolution.second, null, &tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expectEqualStrings("EST", now_local.tzAbbreviation());

    const t4: i32 = 1690840800;
    now_local = try Datetime.fromUnix(t4, Duration.Resolution.second, null, &tz_ny);
    try testing.expectEqualStrings("America/New_York", now_local.tzName());
    try testing.expectEqualStrings("EDT", now_local.tzAbbreviation());
}

test "tz name and abbr correct after conversion" {
    var tz_berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_berlin.deinit();
    var tz_denver = try Tz.fromTzfile("America/Denver", testing.allocator);
    defer _ = tz_denver.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .tz = &tz_berlin });
    var converted: Datetime = try dt.tzConvert(&tz_denver);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());
    try testing.expectEqualStrings("America/Denver", converted.tzName());
    try testing.expectEqualStrings("MST", converted.tzAbbreviation());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 8, .tz = &tz_berlin });
    converted = try dt.tzConvert(&tz_denver);
    try testing.expectEqualStrings("Europe/Berlin", dt.tzName());
    try testing.expectEqualStrings("CEST", dt.tzAbbreviation());
    try testing.expectEqualStrings("America/Denver", converted.tzName());
    try testing.expectEqualStrings("MDT", converted.tzAbbreviation());
}

test "non-existent datetime" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tz = &tzinfo });
    try testing.expectError(ZdtError.NonexistentDatetime, dt);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/Denver", testing.allocator);
    dt = Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tz = &tzinfo });
    try testing.expectError(ZdtError.NonexistentDatetime, dt);
}

test "ambiguous datetime" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tz = &tzinfo });
    try testing.expectError(ZdtError.AmbiguousDatetime, dt);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/Denver", testing.allocator);
    dt = Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tz = &tzinfo });
    try testing.expectError(ZdtError.AmbiguousDatetime, dt);
}

test "ambiguous datetime / DST fold" {
    var tz_berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_berlin.deinit();

    // DST on, offset 7200 s
    var dt_early = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 0, .tz = &tz_berlin });
    // DST off, offset 3600 s
    var dt_late = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 1, .tz = &tz_berlin });
    try testing.expectEqual(7200, dt_early.utc_offset.?.seconds_east);
    try testing.expectEqual(3600, dt_late.utc_offset.?.seconds_east);

    var tz_mountain = try Tz.fromTzfile("America/Denver", testing.allocator);
    defer tz_mountain.deinit();
    dt_early = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .dst_fold = 0, .tz = &tz_mountain });
    dt_late = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .dst_fold = 1, .tz = &tz_mountain });
    try testing.expectEqual(-21600, dt_early.utc_offset.?.seconds_east);
    try testing.expectEqual(-25200, dt_late.utc_offset.?.seconds_east);
}

test "tz without transitions at UTC+9" {
    var tzinfo = try Tz.fromTzfile("Asia/Tokyo", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tz = &tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.utc_offset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tz = &tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.utc_offset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tz = &tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.utc_offset.?.seconds_east);
    dt = try Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tz = &tzinfo });
    try testing.expectEqual(@as(i32, 9 * 3600), dt.utc_offset.?.seconds_east);
}

test "make datetime aware" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try Datetime.fromUnix(0, Duration.Resolution.second, null, null);
    try testing.expect(dt_naive.utc_offset == null);
    try testing.expect(dt_naive.tz == null);

    var dt_aware = try dt_naive.tzLocalize(&tzinfo);
    try testing.expect(dt_aware.tz != null);
    try testing.expect(dt_aware.unix_sec != dt_naive.unix_sec);
    try testing.expect(dt_aware.unix_sec == -3600);
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
    const dt_berlin = try dt_utc.tzLocalize(&tz_Berlin);

    try testing.expect(dt_berlin.utc_offset != null);
    try testing.expect(dt_berlin.unix_sec != dt_utc.unix_sec);
    try testing.expect(dt_berlin.unix_sec == -3600);
    try testing.expect(dt_berlin.year == dt_utc.year);
    try testing.expect(dt_berlin.day == dt_utc.day);
    try testing.expect(dt_berlin.hour == dt_utc.hour);
}

test "replace tz fails for non-existent datetime in target tz" {
    var tz_Berlin = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tz_Berlin.deinit();

    const dt_utc = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .utc_offset = UTCoffset.UTC });
    const err = dt_utc.tzLocalize(&tz_Berlin);

    try testing.expectError(ZdtError.NonexistentDatetime, err);
}

test "convert time zone" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try Datetime.fromUnix(42, Duration.Resolution.nanosecond, null, null);
    const err = dt_naive.tzConvert(&tzinfo);
    try testing.expectError(ZdtError.TzUndefined, err);

    const dt_Berlin = try Datetime.fromUnix(42, Duration.Resolution.nanosecond, null, &tzinfo);

    tzinfo.deinit();
    tzinfo = try Tz.fromTzfile("America/New_York", testing.allocator);
    const dt_NY = try dt_Berlin.tzConvert(&tzinfo);

    try testing.expect(dt_Berlin.unix_sec == dt_NY.unix_sec);
    try testing.expect(dt_Berlin.nanosecond == dt_NY.nanosecond);
    try testing.expect(dt_Berlin.hour != dt_NY.hour);
}

test "floor to date changes UTC offset" {
    var tzinfo = try Tz.fromTzfile("Europe/Berlin", testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 5, .tz = &tzinfo });
    var dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(@as(u8, 0), dt_floored.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(i32, 3600), dt.utc_offset.?.seconds_east);
    try testing.expectEqual(@as(i32, 7200), dt_floored.utc_offset.?.seconds_east);

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 3, .tz = &tzinfo });
    dt_floored = try dt.floorTo(Duration.Timespan.day);
    try testing.expectEqual(@as(u8, 0), dt_floored.hour);
    try testing.expectEqual(@as(u8, 0), dt_floored.minute);
    try testing.expectEqual(@as(u8, 0), dt_floored.second);
    try testing.expectEqual(@as(i32, 7200), dt.utc_offset.?.seconds_east);
    try testing.expectEqual(@as(i32, 3600), dt_floored.utc_offset.?.seconds_east);
}

test "load a lot of zones" {
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
        var tz_a = try Tz.fromTzfile(zone, testing.allocator);
        var dt_a = try Datetime.fromUnix(1, Duration.Resolution.second, null, &tz_a);
        try testing.expect(dt_a.utc_offset != null);
        try testing.expectEqualStrings(zone, dt_a.tzName());
        tz_a.deinit();

        tz_a = try Tz.fromTzdata(zone, testing.allocator);
        dt_a = try Datetime.fromUnix(1, Duration.Resolution.second, null, &tz_a);
        try testing.expect(dt_a.utc_offset != null);
        try testing.expectEqualStrings(zone, dt_a.tzName());
        tz_a.deinit();
    }
}

// the following test is auto-generated by gen_test_tzones.py. do not edit this line and below.

test "conversion between random time zones" {
    var tz_a = try Tz.fromTzfile("US/Samoa", std.testing.allocator);
    var tz_b = try Tz.fromTzfile("Asia/Yerevan", std.testing.allocator);

    var dt_a = try Datetime.fromUnix(-816207319, Duration.Resolution.second, null, &tz_a);
    var dt_b = try Datetime.fromUnix(1921722761, Duration.Resolution.second, null, &tz_b);
    var dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);

    var s_b = std.ArrayList(u8).init(testing.allocator);
    var s_c = std.ArrayList(u8).init(testing.allocator);
    defer s_b.deinit();
    defer s_c.deinit();

    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("2030-11-23T16:52:41-11:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1944-02-20T06:44:41+03:00:00", s_c.items);

    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Canada/Atlantic", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Los_Angeles", std.testing.allocator);
    dt_a = try Datetime.fromUnix(1942114456, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1893647018, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1909-12-29T14:56:22-04:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2031-07-17T21:14:16-07:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Kinshasa", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Australia/Hobart", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1128113058, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(1223021131, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("2008-10-03T09:05:31+01:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1934-04-03T13:15:42+10:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Aqtobe", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Damascus", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-485869856, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1894391592, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1909-12-21T07:55:28+03:48:40", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1954-08-09T14:09:04+02:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Panama", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Africa/Kinshasa", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-999522008, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(719055854, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1992-10-14T04:44:14-05:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1938-04-30T11:59:52+01:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Casablanca", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Baghdad", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1389478107, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-195234029, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1963-10-25T08:19:31+00:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1925-12-21T04:51:33+03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Timbuktu", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Mazatlan", std.testing.allocator);
    dt_a = try Datetime.fromUnix(794111713, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1262529920, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1929-12-29T09:14:40+00:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1995-03-01T19:35:13-07:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Africa/Dar_es_Salaam", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Famagusta", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1846174622, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(364596200, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1981-07-21T23:43:20+03:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1911-07-02T07:58:46+02:15:48", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Australia/Currie", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Bratislava", std.testing.allocator);
    dt_a = try Datetime.fromUnix(1967326856, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(142696408, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1974-07-10T23:53:28+10:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2032-05-05T01:40:56+02:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Toronto", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Cordoba", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-865972273, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-639392452, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1949-09-27T10:59:08-04:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1942-07-24T01:08:47-03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/Samara", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Greenwich", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1571932065, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-782078436, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1945-03-21T07:59:24+04:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1920-03-10T08:12:15+00:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Kuala_Lumpur", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Samara", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1516539100, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(986091715, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("2001-04-01T10:21:55+08:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1921-12-11T14:08:20+03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Dawson_Creek", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/St_Barthelemy", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1215106914, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-487293440, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1954-07-23T17:42:40-07:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1931-07-01T02:18:06-04:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Etc/GMT+1", std.testing.allocator);
    tz_b = try Tz.fromTzfile("GMT", std.testing.allocator);
    dt_a = try Datetime.fromUnix(1367598722, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1473054982, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1923-04-28T17:03:38-01:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2013-05-03T16:32:02+00:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Jayapura", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Pacific/Wallis", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-260468215, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1511958403, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1922-02-02T20:56:05+09:22:48", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1961-09-30T19:43:05+12:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/Oslo", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Pontianak", std.testing.allocator);
    dt_a = try Datetime.fromUnix(824105261, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(477126985, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1985-02-13T08:16:25+01:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1996-02-12T13:07:41+07:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Riyadh", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Argentina/Tucuman", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-444856409, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-2017440120, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1906-01-27T03:04:52+03:06:52", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1955-11-27T01:46:31-03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Argentina/San_Juan", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Asia/Srednekolymsk", std.testing.allocator);
    dt_a = try Datetime.fromUnix(2081029752, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(230882752, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1977-04-26T03:05:52-03:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2035-12-12T10:49:12+11:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("America/Indiana/Indianapolis", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Australia/Tasmania", std.testing.allocator);
    dt_a = try Datetime.fromUnix(1751368983, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(693621470, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1991-12-24T19:37:50-05:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2025-07-01T21:23:03+10:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Australia/Broken_Hill", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Uzhgorod", std.testing.allocator);
    dt_a = try Datetime.fromUnix(715858672, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-373086081, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1958-03-07T06:28:39+09:30:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1992-09-07T12:37:52+03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/London", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Tiraspol", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-293022949, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1445358615, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1924-03-14T07:29:45+00:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1960-09-18T15:44:11+03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Mexico/BajaSur", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Etc/GMT+9", std.testing.allocator);
    dt_a = try Datetime.fromUnix(560485083, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(2064615505, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("2035-06-04T17:18:25-07:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1987-10-05T17:18:03-09:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Asia/Oral", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Argentina/San_Luis", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-1010224506, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(579644539, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1988-05-15T02:22:19+06:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1937-12-27T11:04:54-03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Iceland", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Porto_Acre", std.testing.allocator);
    dt_a = try Datetime.fromUnix(42640281, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(-1385885032, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1926-01-31T15:56:08+00:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1971-05-09T07:31:21-05:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("Europe/Oslo", std.testing.allocator);
    tz_b = try Tz.fromTzfile("Europe/Mariehamn", std.testing.allocator);
    dt_a = try Datetime.fromUnix(1094749082, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(775994453, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1994-08-04T12:00:53+02:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("2004-09-09T19:58:02+03:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();

    tz_a = try Tz.fromTzfile("ROK", std.testing.allocator);
    tz_b = try Tz.fromTzfile("America/Adak", std.testing.allocator);
    dt_a = try Datetime.fromUnix(-44705548, Duration.Resolution.second, null, &tz_a);
    dt_b = try Datetime.fromUnix(788932013, Duration.Resolution.second, null, &tz_b);
    dt_c = try dt_a.tzConvert(&tz_b);
    dt_b = try dt_b.tzConvert(&tz_a);
    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("1995-01-01T12:46:53+09:00:00", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("1968-08-01T02:47:32-11:00:00", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();
}
