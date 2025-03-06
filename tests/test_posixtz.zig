//! test posix tz

const std = @import("std");
const testing = std.testing;
const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const psx = @import("../lib/posixtz.zig");

const log = std.log.scoped(.test_posixtz);

// TODO : add integration tests, with the main Timezone struct
// TODO : add designation tests

test "posix tz has name and abbreviation" {
    var tzinfo = try Tz.fromPOSIXTZ("CET-1CEST,M3.5.0,M10.5.0/3");
    defer tzinfo.deinit();

    var dt = try Datetime.fromFields(.{ .year = 2023, .month = 2, .tz_options = .{ .tz = &tzinfo } });
    try testing.expectEqualStrings("CET-1CEST,M3.5.0,M10.5.0/3", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());

    dt = try Datetime.fromFields(.{ .year = 2023, .month = 8, .tz_options = .{ .tz = &tzinfo } });
    try testing.expectEqualStrings("CET-1CEST,M3.5.0,M10.5.0/3", dt.tzName());
    try testing.expectEqualStrings("CEST", dt.tzAbbreviation());

    dt = try Datetime.fromUnix(1672527600, Duration.Resolution.second, .{ .tz = &tzinfo });
    try testing.expectEqualStrings("CET-1CEST,M3.5.0,M10.5.0/3", dt.tzName());
    try testing.expectEqualStrings("CET", dt.tzAbbreviation());

    dt = try Datetime.fromUnix(1690840800, Duration.Resolution.second, .{ .tz = &tzinfo });
    try testing.expectEqualStrings("CET-1CEST,M3.5.0,M10.5.0/3", dt.tzName());
    try testing.expectEqualStrings("CEST", dt.tzAbbreviation());
}

// The following tests are from CPython's zoneinfo tests;
// https://github.com/python/cpython/blob/main/Lib/test/test_zoneinfo/test_zoneinfo.py
test "posix TZ, valid strings" {
    const tzstrs = [_][]const u8{
        // Extreme offset hour
        "AAA24",
        "AAA+24",
        "AAA-24",
        "AAA24BBB,J60/2,J300/2",
        "AAA+24BBB,J60/2,J300/2",
        "AAA-24BBB,J60/2,J300/2",
        "AAA4BBB24,J60/2,J300/2",
        "AAA4BBB+24,J60/2,J300/2",
        "AAA4BBB-24,J60/2,J300/2",
        // Extreme offset minutes
        "AAA4:00BBB,J60/2,J300/2",
        "AAA4:59BBB,J60/2,J300/2",
        "AAA4BBB5:00,J60/2,J300/2",
        "AAA4BBB5:59,J60/2,J300/2",
        // Extreme offset seconds
        "AAA4:00:00BBB,J60/2,J300/2",
        "AAA4:00:59BBB,J60/2,J300/2",
        "AAA4BBB5:00:00,J60/2,J300/2",
        "AAA4BBB5:00:59,J60/2,J300/2",
        // Extreme total offset
        "AAA24:59:59BBB5,J60/2,J300/2",
        "AAA-24:59:59BBB5,J60/2,J300/2",
        "AAA4BBB24:59:59,J60/2,J300/2",
        "AAA4BBB-24:59:59,J60/2,J300/2",
        // Extreme months
        "AAA4BBB,M12.1.1/2,M1.1.1/2",
        "AAA4BBB,M1.1.1/2,M12.1.1/2",
        // Extreme weeks
        "AAA4BBB,M1.5.1/2,M1.1.1/2",
        "AAA4BBB,M1.1.1/2,M1.5.1/2",
        // Extreme weekday
        "AAA4BBB,M1.1.6/2,M2.1.1/2",
        "AAA4BBB,M1.1.1/2,M2.1.6/2",
        // Extreme numeric offset
        "AAA4BBB,0/2,20/2",
        "AAA4BBB,0/2,0/14",
        "AAA4BBB,20/2,365/2",
        "AAA4BBB,365/2,365/14",
        // Extreme julian offset
        "AAA4BBB,J1/2,J20/2",
        "AAA4BBB,J1/2,J1/14",
        "AAA4BBB,J20/2,J365/2",
        "AAA4BBB,J365/2,J365/14",
        // Extreme transition hour
        "AAA4BBB,J60/167,J300/2",
        "AAA4BBB,J60/+167,J300/2",
        "AAA4BBB,J60/-167,J300/2",
        "AAA4BBB,J60/2,J300/167",
        "AAA4BBB,J60/2,J300/+167",
        "AAA4BBB,J60/2,J300/-167",
        // Extreme transition minutes
        "AAA4BBB,J60/2:00,J300/2",
        "AAA4BBB,J60/2:59,J300/2",
        "AAA4BBB,J60/2,J300/2:00",
        "AAA4BBB,J60/2,J300/2:59",
        // Extreme transition seconds
        "AAA4BBB,J60/2:00:00,J300/2",
        "AAA4BBB,J60/2:00:59,J300/2",
        "AAA4BBB,J60/2,J300/2:00:00",
        "AAA4BBB,J60/2,J300/2:00:59",
        // Extreme total transition time
        "AAA4BBB,J60/167:59:59,J300/2",
        "AAA4BBB,J60/-167:59:59,J300/2",
        "AAA4BBB,J60/2,J300/167:59:59",
        "AAA4BBB,J60/2,J300/-167:59:59",
    };
    for (tzstrs) |valid_str| {
        _ = try psx.parsePosixTzString(valid_str);
    }
}

test "posix TZ invalid string, unquoted alphanumeric" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("+11"));
}

test "posix TZ invalid string, unquoted alphanumeric in DST" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("GMT0+11,M3.2.0/2,M11.1.0/3"));
}

test "posix TZ invalid string, DST but no transition specified" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("PST8PDT"));
}

test "posix TZ invalid string, only one transition rule" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("PST8PDT,M3.2.0/2"));
}

test "posix TZ invalid string, transition rule but no DST" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("GMT,M3.2.0/2,M11.1.0/3"));
}

test "posix TZ invalid offset hours" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA168"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA+168"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA-168"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA+168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA-168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB168,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB+168,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB-168,J60/2,J300/2"));
}

test "posix TZ invalid offset minutes" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4:0BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4:100BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB5:0,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB5:100,J60/2,J300/2"));
}

test "posix TZ invalid offset seconds" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4:00:0BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4:00:100BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB5:00:0,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB5:00:100,J60/2,J300/2"));
}

test "posix TZ completely invalid dates" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1443339,M11.1.0/3"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M3.2.0/2,0349309483959c"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,z,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,z"));
}

test "posix TZ invalid months" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M13.1.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.1.1/2,M13.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M0.1.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.1.1/2,M0.1.1/2"));
}

test "posix TZ invalid weeks" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.6.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.1.1/2,M1.6.1/2"));
}

test "posix TZ invalid weekday" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.1.7/2,M2.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,M1.1.1/2,M2.1.7/2"));
}

test "posix TZ invalid numeric offset" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,-1/2,20/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,1/2,-1/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,367,20/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,1/2,367/2"));
}

test "posix TZ invalid julian offset" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J0/2,J20/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J20/2,J366/2"));
}

test "posix TZ invalid transition time" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2/3,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/2/3"));
}

test "posix TZ invalid transition hour" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/+168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/-168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/168"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/+168"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/-168"));
}

test "posix TZ invalid transition minutes" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2:0,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2:100,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/2:0"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/2:100"));
}

test "posix TZ invalid transition seconds" {
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2:00:0,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2:00:100,J300/2"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/2:00:0"));
    try std.testing.expectError(error.InvalidFormat, psx.parsePosixTzString("AAA4BBB,J60/2,J300/2:00:100"));
}

test "posix TZ EST5EDT,M3.2.0/4:00,M11.1.0/3:00 from zoneinfo_test.py" {
    // Transition to EDT on the 2nd Sunday in March at 4 AM, and
    // transition back on the first Sunday in November at 3AM
    const result = try psx.parsePosixTzString("EST5EDT,M3.2.0/4:00,M11.1.0/3:00");
    try testing.expectEqual(@as(i32, -18000), result.utcOffsetAt(1552107600).seconds_east); // 2019-03-09T00:00:00-05:00
    try testing.expectEqual(@as(i32, -18000), result.utcOffsetAt(1552208340).seconds_east); // 2019-03-10T03:59:00-05:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1572667200).seconds_east); // 2019-11-02T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1572760740).seconds_east); // 2019-11-03T01:59:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1572760800).seconds_east); // 2019-11-03T02:00:00-04:00
    try testing.expectEqual(@as(i32, -18000), result.utcOffsetAt(1572764400).seconds_east); // 2019-11-03T02:00:00-05:00
    try testing.expectEqual(@as(i32, -18000), result.utcOffsetAt(1583657940).seconds_east); // 2020-03-08T03:59:00-05:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1604210340).seconds_east); // 2020-11-01T01:59:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1604210400).seconds_east); // 2020-11-01T02:00:00-04:00
    try testing.expectEqual(@as(i32, -18000), result.utcOffsetAt(1604214000).seconds_east); // 2020-11-01T02:00:00-05:00
}

test "posix TZ GMT0BST-1,M3.5.0/1:00,M10.5.0/2:00 from zoneinfo_test.py" {
    // Transition to BST happens on the last Sunday in March at 1 AM GMT
    // and the transition back happens the last Sunday in October at 2AM BST
    const result = try psx.parsePosixTzString("GMT0BST-1,M3.5.0/1:00,M10.5.0/2:00");
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1553904000).seconds_east); // 2019-03-30T00:00:00+00:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1553993940).seconds_east); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1553994000).seconds_east); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1572044400).seconds_east); // 2019-10-26T00:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1572134340).seconds_east); // 2019-10-27T00:59:00+01:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1585443540).seconds_east); // 2020-03-29T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1585443600).seconds_east); // 2020-03-29T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1603583940).seconds_east); // 2020-10-25T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1603584000).seconds_east); // 2020-10-25T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1603591200).seconds_east); // 2020-10-25T02:00:00+00:00
}

test "posix TZ AEST-10AEDT,M10.1.0/2,M4.1.0/3 from zoneinfo_test.py" {
    // Austrialian time zone - DST start is chronologically first
    const result = try psx.parsePosixTzString("AEST-10AEDT,M10.1.0/2,M4.1.0/3");
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1554469200).seconds_east); // 2019-04-06T00:00:00+11:00
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1554562740).seconds_east); // 2019-04-07T01:59:00+11:00
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1554562740).seconds_east); // 2019-04-07T01:59:00+11:00
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1554562800).seconds_east); // 2019-04-07T02:00:00+11:00
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1554562860).seconds_east); // 2019-04-07T02:01:00+11:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1554566400).seconds_east); // 2019-04-07T02:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1554566460).seconds_east); // 2019-04-07T02:01:00+10:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1554570000).seconds_east); // 2019-04-07T03:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1554570000).seconds_east); // 2019-04-07T03:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1570197600).seconds_east); // 2019-10-05T00:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), result.utcOffsetAt(1570291140).seconds_east); // 2019-10-06T01:59:00+10:00
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1570291200).seconds_east); // 2019-10-06T03:00:00+11:00
}

test "posix TZ IST-1GMT0,M10.5.0,M3.5.0/1 from zoneinfo_test.py" {
    // Irish time zone - negative DST
    const result = try psx.parsePosixTzString("IST-1GMT0,M10.5.0,M3.5.0/1");
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1553904000).seconds_east); // 2019-03-30T00:00:00+00:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1553993940).seconds_east); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(true, result.utcOffsetAt(1553993940).is_dst); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1553994000).seconds_east); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(false, result.utcOffsetAt(1553994000).is_dst); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1572044400).seconds_east); // 2019-10-26T00:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1572134340).seconds_east); // 2019-10-27T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1572134400).seconds_east); // 2019-10-27T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1572138000).seconds_east); // 2019-10-27T01:00:00+00:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1572141600).seconds_east); // 2019-10-27T02:00:00+00:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1585443540).seconds_east); // 2020-03-29T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1585443600).seconds_east); // 2020-03-29T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1603583940).seconds_east); // 2020-10-25T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), result.utcOffsetAt(1603584000).seconds_east); // 2020-10-25T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), result.utcOffsetAt(1603591200).seconds_east); // 2020-10-25T02:00:00+00:00
}

test "posix TZ <+11>-11 from zoneinfo_test.py" {
    // Pacific/Kosrae: Fixed offset zone with a quoted numerical tzname
    const result = try psx.parsePosixTzString("<+11>-11");
    try testing.expectEqual(@as(i32, 39600), result.utcOffsetAt(1577797200).seconds_east); // 2020-01-01T00:00:00+11:00
}

test "posix TZ <-04>4<-03>,M9.1.6/24,M4.1.6/24 from zoneinfo_test.py" {
    // Quoted STD and DST, transitions at 24:00
    const result = try psx.parsePosixTzString("<-04>4<-03>,M9.1.6/24,M4.1.6/24");
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1588305600).seconds_east); // 2020-05-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1604199600).seconds_east); // 2020-11-01T00:00:00-03:00
}

test "posix TZ EST5EDT,0/0,J365/25 from zoneinfo_test.py" {
    // Permanent daylight saving time is modeled with transitions at 0/0
    // and J365/25, as mentioned in RFC 8536 Section 3.3.1
    const result = try psx.parsePosixTzString("EST5EDT,0/0,J365/25");
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1546315200).seconds_east); // 2019-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1559361600).seconds_east); // 2019-06-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1577851199).seconds_east); // 2019-12-31T23:59:59.999999-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1577851200).seconds_east); // 2020-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1583035200).seconds_east); // 2020-03-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1590984000).seconds_east); // 2020-06-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(1609473599).seconds_east); // 2020-12-31T23:59:59.999999-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(13569480000).seconds_east); // 2400-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(13574664000).seconds_east); // 2400-03-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), result.utcOffsetAt(13601102399).seconds_east); // 2400-12-31T23:59:59.999999-04:00
}

test "posix TZ AAA3BBB,J60/12,J305/12 from zoneinfo_test.py" {
    // Transitions on March 1st and November 1st of each year
    const result = try psx.parsePosixTzString("AAA3BBB,J60/12,J305/12");
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1546311600).seconds_east); // 2019-01-01T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1551322800).seconds_east); // 2019-02-28T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1551452340).seconds_east); // 2019-03-01T11:59:00-03:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1551452400).seconds_east); // 2019-03-01T13:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1572613140).seconds_east); // 2019-11-01T10:59:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1572613200).seconds_east); // 2019-11-01T11:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1572616800).seconds_east); // 2019-11-01T11:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1572620400).seconds_east); // 2019-11-01T12:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1577847599).seconds_east); // 2019-12-31T23:59:59.999999-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1577847600).seconds_east); // 2020-01-01T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1582945200).seconds_east); // 2020-02-29T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1583074740).seconds_east); // 2020-03-01T11:59:00-03:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1583074800).seconds_east); // 2020-03-01T13:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1604235540).seconds_east); // 2020-11-01T10:59:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1604235600).seconds_east); // 2020-11-01T11:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1604239200).seconds_east); // 2020-11-01T11:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1604242800).seconds_east); // 2020-11-01T12:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1609469999).seconds_east); // 2020-12-31T23:59:59.999999-03:00
}

test "posix TZ <-03>3<-02>,M3.5.0/-2,M10.5.0/-1 from zoneinfo_test.py" {
    // Taken from America/Godthab, this rule has a transition on the
    // Saturday before the last Sunday of March and October, at 22:00 and 23:00,
    // respectively. This is encoded with negative start and end transition times.
    const result = try psx.parsePosixTzString("<-03>3<-02>,M3.5.0/-2,M10.5.0/-1");
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1585278000).seconds_east); // 2020-03-27T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1585443599).seconds_east); // 2020-03-28T21:59:59-03:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1585443600).seconds_east); // 2020-03-28T23:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1603580400).seconds_east); // 2020-10-24T21:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1603584000).seconds_east); // 2020-10-24T22:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1603587600).seconds_east); // 2020-10-24T22:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1603591200).seconds_east); // 2020-10-24T23:00:00-03:00
}

test "posix TZ AAA3BBB,M3.2.0/01:30,M11.1.0/02:15:45 from zoneinfo_test.py" {
    // Transition times with minutes and seconds
    const result = try psx.parsePosixTzString("AAA3BBB,M3.2.0/01:30,M11.1.0/02:15:45");
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1331438400).seconds_east); // 2012-03-11T01:00:00-03:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1331440200).seconds_east); // 2012-03-11T02:30:00-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1351998944).seconds_east); // 2012-11-04T01:15:44.999999-02:00
    try testing.expectEqual(@as(i32, -7200), result.utcOffsetAt(1351998945).seconds_east); // 2012-11-04T01:15:45-02:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1352002545).seconds_east); // 2012-11-04T01:15:45-03:00
    try testing.expectEqual(@as(i32, -10800), result.utcOffsetAt(1352006145).seconds_east); // 2012-11-04T02:15:45-03:00
}
