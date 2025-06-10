//! test posix tz

const std = @import("std");
const testing = std.testing;
const zdt = @import("zdt");
const ZdtError = zdt.ZdtError;
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;

const log = std.log.scoped(.test_posixtz);

test "posix tz has name and abbreviation" {
    var tzinfo = try Tz.fromPosixTz("CET-1CEST,M3.5.0,M10.5.0/3");

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

test "Japan has only std time" {
    const tzinfo = try Tz.fromPosixTz("JST-9");
    const dt_early = try Datetime.fromFields(.{ .year = 2025, .month = 2, .tz_options = .{ .tz = &tzinfo } });
    const dt_late = try Datetime.fromFields(.{ .year = 2025, .month = 8, .tz_options = .{ .tz = &tzinfo } });
    try testing.expectEqual(9 * 3600, dt_early.utc_offset.?.seconds_east);
    try testing.expectEqual(9 * 3600, dt_late.utc_offset.?.seconds_east);
    try testing.expectEqualStrings("JST-9", dt_early.tzName());
    try testing.expectEqualStrings("JST", dt_early.tzAbbreviation());
    try testing.expectEqualStrings("JST-9", dt_late.tzName());
    try testing.expectEqualStrings("JST", dt_late.tzAbbreviation());
}

test "non-existing / ambiguous datetime" {
    var tzinfo = try Tz.fromPosixTz("CET-1CEST,M3.5.0,M10.5.0/3");
    var err = Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tz_options = .{ .tz = &tzinfo } });
    try testing.expectError(ZdtError.AmbiguousDatetime, err);

    err = Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tz_options = .{ .tz = &tzinfo } });
    try testing.expectError(ZdtError.NonexistentDatetime, err);

    // DST on, offset 7200 s
    const dt_early = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 0, .tz_options = .{ .tz = &tzinfo } });
    // DST off, offset 3600 s
    const dt_late = try Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .dst_fold = 1, .tz_options = .{ .tz = &tzinfo } });

    try testing.expectEqual(7200, dt_early.utc_offset.?.seconds_east);
    try testing.expectEqual(3600, dt_late.utc_offset.?.seconds_east);
}
