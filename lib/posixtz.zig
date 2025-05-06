//! POSIXTZ time zone

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const cal = @import("./calendar.zig");
const UTCoffset = @import("./UTCoffset.zig");
const FormatError = @import("./errors.zig").FormatError;
const TzError = @import("./errors.zig").TzError;

/// The default DST transition time is 2 am local time
const default_transition_time: i32 = 2 * std.time.s_per_hour;

/// Do not accept POSIX TZ strings longer than this.
/// The value is arbitrary but seems reasonable.
pub const max_string_len: usize = 64;

/// Time zone rules from POSIX TZ string
pub const PosixTz = struct {
    std_offset: i32,
    std_designation: []const u8, // safe to use []const u8 / pointers here since the basis also is []const u8
    dst_offset: ?i32 = null,
    dst_designation: ?[]const u8 = null,
    dst_range: ?struct { start: Rule, end: Rule } = null,

    pub const Rule = union(enum) {
        JulianDay: struct {
            /// 1 <= day <= 365. Leap days are not counted and are impossible to refer to
            day: u16,
            /// Transition time
            time: i32 = default_transition_time,
        },
        JulianDayZero: struct {
            /// 0 <= day <= 365. Leap days are counted, and can be referred to.
            day: u16,
            /// Transition time
            time: i32 = default_transition_time,
        },
        /// In the format of "Mm.n.d", where m = month, n = n, and d = day.
        MonthNthWeekDay: struct {
            /// Month of the year. 1 <= month <= 12
            month: u8,
            /// Specifies which of the weekdays should be used. Does NOT specify the week of the month! 1 <= week <= 5.
            ///
            /// Let's use M3.2.0 as an example. The month is 3, which translates to March.
            /// The day is 0, which means Sunday. `n` is 2, which means the second Sunday
            /// in the month, NOT Sunday of the second week!
            ///
            /// In 2021, this is difference between 2023-03-07 (Sunday of the second week of March)
            /// and 2023-03-14 (the Second Sunday of March).
            ///
            /// * When n is 1, it means the first week in which the day `day` occurs.
            /// * 5 is a special case. When n is 5, it means "the last day `day` in the month", which may occur in either the fourth or the fifth week.
            n: u8,
            /// Day of the week. 0 <= day <= 6. Day zero is Sunday.
            day: u8,
            /// Transition time
            time: i32 = default_transition_time,
        },

        pub fn isAtStartOfYear(rule: Rule) bool {
            switch (rule) {
                .JulianDay => |j| return j.day == 1 and j.time == 0,
                .JulianDayZero => |j| return j.day == 0 and j.time == 0,
                .MonthNthWeekDay => |mwd| return mwd.month == 1 and mwd.n == 1 and mwd.day == 0 and mwd.time == 0,
            }
        }

        pub fn isAtEndOfYear(rule: Rule) bool {
            switch (rule) {
                .JulianDay => |j| return j.day == 365 and j.time >= 24,
                // Since JulianDayZero dates account for leap years, it would vary depending on the year.
                .JulianDayZero => return false,
                // There is also no way to specify "end of the year" with MonthNthWeekDay rules
                .MonthNthWeekDay => return false,
            }
        }

        /// Returned value is the Unix time of the transition in given year,
        /// including the local UTC offset (!)
        pub fn toUnixTimeLocal(rule: Rule, year: i16) i64 {
            const is_leap: bool = cal.isLeapYear(year);
            const start_of_year: i32 = cal.dateToRD(.{ .year = year, .month = 1, .day = 1 });
            var t: i64 = @as(i64, start_of_year) * std.time.s_per_day;

            switch (rule) {
                .JulianDay => |j| {
                    var x: i64 = j.day;
                    if (x < 60 or !is_leap) x -= 1;
                    t += std.time.s_per_day * x + j.time;
                },
                .JulianDayZero => |j| {
                    t += std.time.s_per_day * @as(i64, j.day) + j.time;
                },
                .MonthNthWeekDay => |mwd| {
                    const days_since_epoch: i32 = cal.dateToRD(.{ .year = year, .month = mwd.month, .day = 1 });
                    const first_weekday_of_month = cal.weekdayFromUnixdays(days_since_epoch);
                    const weekday_offset_for_month = if (first_weekday_of_month <= mwd.day)
                        // the first matching weekday is during the first week of the month
                        mwd.day - first_weekday_of_month
                    else
                        // the first matching weekday is during the second week of the month
                        mwd.day + 7 - first_weekday_of_month;

                    const days_since_start_of_month = switch (mwd.n) {
                        1...4 => |n| (n - 1) * 7 + weekday_offset_for_month,
                        5 => if (weekday_offset_for_month + 28 >= cal.daysInMonth(mwd.month, is_leap))
                            // the last matching weekday is during the 4th week of the month
                            21 + weekday_offset_for_month
                        else
                            // the last matching weekday is during the 5th week of the month
                            28 + weekday_offset_for_month,
                        else => unreachable,
                    };

                    t += (days_since_epoch - start_of_year) * std.time.s_per_day +
                        std.time.s_per_day * @as(i64, days_since_start_of_month) +
                        mwd.time;
                },
            }
            return t;
        }
    };

    /// Get the offset from UTC at given Unix time, including Daylight Saving Time
    pub fn utcOffsetAt(tz: *const PosixTz, unix_seconds: i64) TzError!UTCoffset {
        const dst_designation = tz.dst_designation orelse {
            assert(tz.dst_offset == null);
            assert(tz.dst_range == null);
            return try UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false);
        };
        if (tz.dst_range) |range| {
            const ymd = cal.rdToDate(@truncate(@divFloor(unix_seconds, std.time.s_per_day)));
            const start_dst = range.start.toUnixTimeLocal(@as(i16, @intCast(ymd.year))) - tz.std_offset;
            const end_dst = range.end.toUnixTimeLocal(@as(i16, @intCast(ymd.year))) - tz.dst_offset.?;
            const is_dst_all_year = range.start.isAtStartOfYear() and range.end.isAtEndOfYear();

            if (is_dst_all_year) {
                return try UTCoffset.fromSeconds(tz.dst_offset.?, dst_designation, true);
            }

            if (start_dst < end_dst) {
                if (unix_seconds >= start_dst and unix_seconds < end_dst) {
                    return try UTCoffset.fromSeconds(tz.dst_offset.?, dst_designation, true);
                } else {
                    return try UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false);
                }
            } else {
                if (unix_seconds >= end_dst and unix_seconds < start_dst) {
                    return try UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false);
                } else {
                    return try UTCoffset.fromSeconds(tz.dst_offset.?, dst_designation, true);
                }
            }
        }
        return try UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false);
    }
};

/// Parse a POSIX TZ string like 'PST8PDT,M3.2.0,M11.1.0' to a set of rules and
/// offsets from UTC.
pub fn parsePosixTzString(string: []const u8) FormatError!PosixTz {
    if (string.len == 0) return FormatError.EmptyString;
    if (string.len > max_string_len) return FormatError.InvalidFormat;

    var result = PosixTz{ .std_designation = undefined, .std_offset = undefined };
    var idx: usize = 0;

    result.std_designation = try parseDesignation(string, &idx);

    // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
    result.std_offset = try parseHHmmss(string[idx..], &idx) * -1;
    if (idx >= string.len) return result;

    if (string[idx] != ',') {
        result.dst_designation = try parseDesignation(string, &idx);

        if (idx < string.len and string[idx] != ',') {
            // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
            result.dst_offset = try parseHHmmss(string[idx..], &idx) * -1;
        } else {
            result.dst_offset = result.std_offset + std.time.s_per_hour;
        }

        if (idx >= string.len) return result;
    }

    assert(string[idx] == ',');
    idx += 1;

    if (std.mem.indexOf(u8, string[idx..], ",")) |_end_of_start_rule| {
        const end_of_start_rule = idx + _end_of_start_rule;
        result.dst_range = .{
            .start = try parseRule(string[idx..end_of_start_rule]),
            .end = try parseRule(string[end_of_start_rule + 1 ..]),
        };
    } else {
        return FormatError.InvalidFormat;
    }

    return result;
}

/// Parse a POSIX TZ designation such as 'PST' in 'PST8PDT,M3.2.0,M11.1.0'
fn parseDesignation(string: []const u8, idx: *usize) FormatError![]const u8 {
    const quoted = string[idx.*] == '<';
    if (quoted) idx.* += 1;
    const start = idx.*;
    while (idx.* < string.len) : (idx.* += 1) {
        if ((quoted and string[idx.*] == '>') or
            (!quoted and !std.ascii.isAlphabetic(string[idx.*])))
        {
            const designation = string[start..idx.*];

            // The designation must be at least one character long!
            if (designation.len == 0) return FormatError.InvalidFormat;

            if (quoted) idx.* += 1;
            return designation;
        }
    }
    return FormatError.InvalidFormat;
}

/// Parse a POSIX TZ rule such as 'M3.2.0' in 'PST8PDT,M3.2.0,M11.1.0'
/// to machine-readable representation of 'DST starts second Sunday in March'
fn parseRule(_string: []const u8) FormatError!PosixTz.Rule {
    var string = _string;
    if (string.len < 2) return FormatError.InvalidFormat;

    const time: i32 = if (std.mem.indexOf(u8, string, "/")) |start_of_time| parse_time: {
        const time_string = string[start_of_time + 1 ..];
        var i: usize = 0;
        const time = try parseHHmmss(time_string, &i);
        // The time at the end of the rule should be the last thing in the string. Fixes the parsing to return
        // an error in cases like "/2/3", where they have some extra characters.
        if (i != time_string.len) return FormatError.InvalidFormat;
        string = string[0..start_of_time];
        break :parse_time time;
    } else default_transition_time;

    switch (string[0]) {
        'J' => {
            const julian_day1 = try std.fmt.parseInt(u16, string[1..], 10);
            if (julian_day1 < 1 or julian_day1 > 365) return FormatError.InvalidFormat;
            return PosixTz.Rule{ .JulianDay = .{ .day = julian_day1, .time = time } };
        },
        '0'...'9' => {
            const julian_day0 = try std.fmt.parseInt(u16, string[0..], 10);
            if (julian_day0 > 365) return error.InvalidFormat;
            return PosixTz.Rule{ .JulianDayZero = .{ .day = julian_day0, .time = time } };
        },
        'M' => {
            var split_iter = std.mem.splitScalar(u8, string[1..], '.');
            const m_str = split_iter.next() orelse return FormatError.InvalidFormat;
            const n_str = split_iter.next() orelse return FormatError.InvalidFormat;
            const d_str = split_iter.next() orelse return FormatError.InvalidFormat;
            const m = try std.fmt.parseInt(u8, m_str, 10);
            const n = try std.fmt.parseInt(u8, n_str, 10);
            const d = try std.fmt.parseInt(u8, d_str, 10);
            if (m < 1 or m > 12) return FormatError.InvalidFormat;
            if (n < 1 or n > 5) return FormatError.InvalidFormat;
            if (d > 6) return FormatError.InvalidFormat;
            return PosixTz.Rule{ .MonthNthWeekDay = .{ .month = m, .n = n, .day = d, .time = time } };
        },
        else => return FormatError.InvalidFormat,
    }
}

/// Parses hh[:mm[:ss]] to number of seconds. Hours may be one digit long. Minutes and seconds must be two digits.
fn parseHHmmss(string: []const u8, idx_ptr: *usize) FormatError!i32 {
    var _string = string;
    var sign: i2 = 1;
    if (_string[0] == '+') {
        _string = _string[1..];
        idx_ptr.* += 1;
    } else if (_string[0] == '-') {
        sign = -1;
        _string = _string[1..];
        idx_ptr.* += 1;
    }

    for (_string, 0..) |c, i| {
        if (!(std.ascii.isDigit(c) or c == ':')) {
            _string = _string[0..i];
            break;
        }
        idx_ptr.* += 1;
    }

    var result: i32 = 0;

    var segment_iter = std.mem.splitScalar(u8, _string, ':');
    const hour_string = segment_iter.next() orelse return FormatError.EmptyString;
    const hours = std.fmt.parseInt(u32, hour_string, 10) catch return FormatError.InvalidFormat;
    if (hours > 167) return FormatError.InvalidFormat;
    result += std.time.s_per_hour * @as(i32, @intCast(hours));

    if (segment_iter.next()) |minute_string| {
        if (minute_string.len != 2) {
            return FormatError.InvalidFormat;
        }
        const minutes = try std.fmt.parseInt(u32, minute_string, 10);
        if (minutes > 59) return FormatError.InvalidFormat;
        result += std.time.s_per_min * @as(i32, @intCast(minutes));
    }

    if (segment_iter.next()) |second_string| {
        if (second_string.len != 2) {
            return FormatError.InvalidFormat;
        }
        const seconds = try std.fmt.parseInt(u8, second_string, 10);
        if (seconds > 59) return FormatError.InvalidFormat;
        result += seconds;
    }

    return result * sign;
}

//----------------------------------------------------------------------------------------------------

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
        _ = try parsePosixTzString(valid_str);
    }
}

test "posix TZ invalid string, unquoted alphanumeric" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("+11"));
}

test "posix TZ invalid string, unquoted alphanumeric in DST" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("GMT0+11,M3.2.0/2,M11.1.0/3"));
}

test "posix TZ invalid string, DST but no transition specified" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("PST8PDT"));
}

test "posix TZ invalid string, only one transition rule" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("PST8PDT,M3.2.0/2"));
}

test "posix TZ invalid string, transition rule but no DST" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("GMT,M3.2.0/2,M11.1.0/3"));
}

test "posix TZ invalid string, empty" {
    try std.testing.expectError(error.EmptyString, parsePosixTzString(""));
}

test "posix TZ invalid string, too long" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"));
}

test "posix TZ invalid offset hours" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA168"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA+168"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA-168"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA+168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA-168BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB168,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB+168,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB-168,J60/2,J300/2"));
}

test "posix TZ invalid offset minutes" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4:0BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4:100BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB5:0,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB5:100,J60/2,J300/2"));
}

test "posix TZ invalid offset seconds" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4:00:0BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4:00:100BBB,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB5:00:0,J60/2,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB5:00:100,J60/2,J300/2"));
}

test "posix TZ completely invalid dates" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1443339,M11.1.0/3"));
    try std.testing.expectError(error.Overflow, parsePosixTzString("AAA4BBB,M3.2.0/2,0349309483959c"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,z,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,z"));
}

test "posix TZ invalid months" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M13.1.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.1.1/2,M13.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M0.1.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.1.1/2,M0.1.1/2"));
}

test "posix TZ invalid weeks" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.6.1/2,M1.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.1.1/2,M1.6.1/2"));
}

test "posix TZ invalid weekday" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.1.7/2,M2.1.1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,M1.1.1/2,M2.1.7/2"));
}

test "posix TZ invalid numeric offset" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,-1/2,20/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,1/2,-1/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,367,20/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,1/2,367/2"));
}

test "posix TZ invalid julian offset" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J0/2,J20/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J20/2,J366/2"));
}

test "posix TZ invalid transition time" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2/3,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/2/3"));
}

test "posix TZ invalid transition hour" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/+168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/-168,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/168"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/+168"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/-168"));
}

test "posix TZ invalid transition minutes" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2:0,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2:100,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/2:0"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/2:100"));
}

test "posix TZ invalid transition seconds" {
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2:00:0,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2:00:100,J300/2"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/2:00:0"));
    try std.testing.expectError(error.InvalidFormat, parsePosixTzString("AAA4BBB,J60/2,J300/2:00:100"));
}

test "posix TZ EST5EDT,M3.2.0/4:00,M11.1.0/3:00 from zoneinfo_test.py" {
    // Transition to EDT on the 2nd Sunday in March at 4 AM, and
    // transition back on the first Sunday in November at 3AM
    const result = try parsePosixTzString("EST5EDT,M3.2.0/4:00,M11.1.0/3:00");
    try testing.expectEqual(@as(i32, -18000), (try result.utcOffsetAt(1552107600)).seconds_east); // 2019-03-09T00:00:00-05:00
    try testing.expectEqual(@as(i32, -18000), (try result.utcOffsetAt(1552208340)).seconds_east); // 2019-03-10T03:59:00-05:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1572667200)).seconds_east); // 2019-11-02T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1572760740)).seconds_east); // 2019-11-03T01:59:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1572760800)).seconds_east); // 2019-11-03T02:00:00-04:00
    try testing.expectEqual(@as(i32, -18000), (try result.utcOffsetAt(1572764400)).seconds_east); // 2019-11-03T02:00:00-05:00
    try testing.expectEqual(@as(i32, -18000), (try result.utcOffsetAt(1583657940)).seconds_east); // 2020-03-08T03:59:00-05:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1604210340)).seconds_east); // 2020-11-01T01:59:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1604210400)).seconds_east); // 2020-11-01T02:00:00-04:00
    try testing.expectEqual(@as(i32, -18000), (try result.utcOffsetAt(1604214000)).seconds_east); // 2020-11-01T02:00:00-05:00
}

test "posix TZ GMT0BST-1,M3.5.0/1:00,M10.5.0/2:00 from zoneinfo_test.py" {
    // Transition to BST happens on the last Sunday in March at 1 AM GMT
    // and the transition back happens the last Sunday in October at 2AM BST
    const result = try parsePosixTzString("GMT0BST-1,M3.5.0/1:00,M10.5.0/2:00");
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1553904000)).seconds_east); // 2019-03-30T00:00:00+00:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1553993940)).seconds_east); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1553994000)).seconds_east); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1572044400)).seconds_east); // 2019-10-26T00:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1572134340)).seconds_east); // 2019-10-27T00:59:00+01:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1585443540)).seconds_east); // 2020-03-29T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1585443600)).seconds_east); // 2020-03-29T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1603583940)).seconds_east); // 2020-10-25T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1603584000)).seconds_east); // 2020-10-25T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1603591200)).seconds_east); // 2020-10-25T02:00:00+00:00
}

test "posix TZ AEST-10AEDT,M10.1.0/2,M4.1.0/3 from zoneinfo_test.py" {
    // Austrialian time zone - DST start is chronologically first
    const result = try parsePosixTzString("AEST-10AEDT,M10.1.0/2,M4.1.0/3");
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1554469200)).seconds_east); // 2019-04-06T00:00:00+11:00
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1554562740)).seconds_east); // 2019-04-07T01:59:00+11:00
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1554562740)).seconds_east); // 2019-04-07T01:59:00+11:00
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1554562800)).seconds_east); // 2019-04-07T02:00:00+11:00
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1554562860)).seconds_east); // 2019-04-07T02:01:00+11:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1554566400)).seconds_east); // 2019-04-07T02:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1554566460)).seconds_east); // 2019-04-07T02:01:00+10:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1554570000)).seconds_east); // 2019-04-07T03:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1554570000)).seconds_east); // 2019-04-07T03:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1570197600)).seconds_east); // 2019-10-05T00:00:00+10:00
    try testing.expectEqual(@as(i32, 36000), (try result.utcOffsetAt(1570291140)).seconds_east); // 2019-10-06T01:59:00+10:00
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1570291200)).seconds_east); // 2019-10-06T03:00:00+11:00
}

test "posix TZ IST-1GMT0,M10.5.0,M3.5.0/1 from zoneinfo_test.py" {
    // Irish time zone - negative DST
    const result = try parsePosixTzString("IST-1GMT0,M10.5.0,M3.5.0/1");
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1553904000)).seconds_east); // 2019-03-30T00:00:00+00:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1553993940)).seconds_east); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(true, (try result.utcOffsetAt(1553993940)).is_dst); // 2019-03-31T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1553994000)).seconds_east); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(false, (try result.utcOffsetAt(1553994000)).is_dst); // 2019-03-31T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1572044400)).seconds_east); // 2019-10-26T00:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1572134340)).seconds_east); // 2019-10-27T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1572134400)).seconds_east); // 2019-10-27T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1572138000)).seconds_east); // 2019-10-27T01:00:00+00:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1572141600)).seconds_east); // 2019-10-27T02:00:00+00:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1585443540)).seconds_east); // 2020-03-29T00:59:00+00:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1585443600)).seconds_east); // 2020-03-29T02:00:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1603583940)).seconds_east); // 2020-10-25T00:59:00+01:00
    try testing.expectEqual(@as(i32, 3600), (try result.utcOffsetAt(1603584000)).seconds_east); // 2020-10-25T01:00:00+01:00
    try testing.expectEqual(@as(i32, 0), (try result.utcOffsetAt(1603591200)).seconds_east); // 2020-10-25T02:00:00+00:00
}

test "posix TZ <+11>-11 from zoneinfo_test.py" {
    // Pacific/Kosrae: Fixed offset zone with a quoted numerical tzname
    const result = try parsePosixTzString("<+11>-11");
    try testing.expectEqual(@as(i32, 39600), (try result.utcOffsetAt(1577797200)).seconds_east); // 2020-01-01T00:00:00+11:00
}

test "posix TZ <-04>4<-03>,M9.1.6/24,M4.1.6/24 from zoneinfo_test.py" {
    // Quoted STD and DST, transitions at 24:00
    const result = try parsePosixTzString("<-04>4<-03>,M9.1.6/24,M4.1.6/24");
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1588305600)).seconds_east); // 2020-05-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1604199600)).seconds_east); // 2020-11-01T00:00:00-03:00
}

test "posix TZ EST5EDT,0/0,J365/25 from zoneinfo_test.py" {
    // Permanent daylight saving time is modeled with transitions at 0/0
    // and J365/25, as mentioned in RFC 8536 Section 3.3.1
    const result = try parsePosixTzString("EST5EDT,0/0,J365/25");
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1546315200)).seconds_east); // 2019-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1559361600)).seconds_east); // 2019-06-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1577851199)).seconds_east); // 2019-12-31T23:59:59.999999-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1577851200)).seconds_east); // 2020-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1583035200)).seconds_east); // 2020-03-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1590984000)).seconds_east); // 2020-06-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(1609473599)).seconds_east); // 2020-12-31T23:59:59.999999-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(13569480000)).seconds_east); // 2400-01-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(13574664000)).seconds_east); // 2400-03-01T00:00:00-04:00
    try testing.expectEqual(@as(i32, -14400), (try result.utcOffsetAt(13601102399)).seconds_east); // 2400-12-31T23:59:59.999999-04:00
}

test "posix TZ AAA3BBB,J60/12,J305/12 from zoneinfo_test.py" {
    // Transitions on March 1st and November 1st of each year
    const result = try parsePosixTzString("AAA3BBB,J60/12,J305/12");
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1546311600)).seconds_east); // 2019-01-01T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1551322800)).seconds_east); // 2019-02-28T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1551452340)).seconds_east); // 2019-03-01T11:59:00-03:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1551452400)).seconds_east); // 2019-03-01T13:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1572613140)).seconds_east); // 2019-11-01T10:59:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1572613200)).seconds_east); // 2019-11-01T11:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1572616800)).seconds_east); // 2019-11-01T11:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1572620400)).seconds_east); // 2019-11-01T12:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1577847599)).seconds_east); // 2019-12-31T23:59:59.999999-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1577847600)).seconds_east); // 2020-01-01T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1582945200)).seconds_east); // 2020-02-29T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1583074740)).seconds_east); // 2020-03-01T11:59:00-03:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1583074800)).seconds_east); // 2020-03-01T13:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1604235540)).seconds_east); // 2020-11-01T10:59:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1604235600)).seconds_east); // 2020-11-01T11:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1604239200)).seconds_east); // 2020-11-01T11:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1604242800)).seconds_east); // 2020-11-01T12:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1609469999)).seconds_east); // 2020-12-31T23:59:59.999999-03:00
}

test "posix TZ <-03>3<-02>,M3.5.0/-2,M10.5.0/-1 from zoneinfo_test.py" {
    // Taken from America/Godthab, this rule has a transition on the
    // Saturday before the last Sunday of March and October, at 22:00 and 23:00,
    // respectively. This is encoded with negative start and end transition times.
    const result = try parsePosixTzString("<-03>3<-02>,M3.5.0/-2,M10.5.0/-1");
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1585278000)).seconds_east); // 2020-03-27T00:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1585443599)).seconds_east); // 2020-03-28T21:59:59-03:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1585443600)).seconds_east); // 2020-03-28T23:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1603580400)).seconds_east); // 2020-10-24T21:00:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1603584000)).seconds_east); // 2020-10-24T22:00:00-02:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1603587600)).seconds_east); // 2020-10-24T22:00:00-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1603591200)).seconds_east); // 2020-10-24T23:00:00-03:00
}

test "posix TZ AAA3BBB,M3.2.0/01:30,M11.1.0/02:15:45 from zoneinfo_test.py" {
    // Transition times with minutes and seconds
    const result = try parsePosixTzString("AAA3BBB,M3.2.0/01:30,M11.1.0/02:15:45");
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1331438400)).seconds_east); // 2012-03-11T01:00:00-03:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1331440200)).seconds_east); // 2012-03-11T02:30:00-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1351998944)).seconds_east); // 2012-11-04T01:15:44.999999-02:00
    try testing.expectEqual(@as(i32, -7200), (try result.utcOffsetAt(1351998945)).seconds_east); // 2012-11-04T01:15:45-02:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1352002545)).seconds_east); // 2012-11-04T01:15:45-03:00
    try testing.expectEqual(@as(i32, -10800), (try result.utcOffsetAt(1352006145)).seconds_east); // 2012-11-04T02:15:45-03:00
}
