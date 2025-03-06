//! POSIXTZ time zone

const std = @import("std");
const assert = std.debug.assert;
const cal = @import("calendar.zig");
const UTCoffset = @import("./UTCoffset.zig");

const log = std.log.scoped(.test_posixtz);

/// Time zone rules from POSIX TZ string
pub const Tz = struct {
    std_designation: []const u8,
    std_offset: i32,
    dst_designation: ?[]const u8 = null,
    dst_offset: i32 = 0,
    dst_range: ?struct { start: Rule, end: Rule } = null,

    pub const Rule = union(enum) {
        JulianDay: struct {
            /// 1 <= day <= 365. Leap days are not counted and are impossible to refer to
            day: u16,
            /// The default DST transition time is 02:00:00 local time
            time: i32 = 2 * std.time.s_per_hour,
        },
        JulianDayZero: struct {
            /// 0 <= day <= 365. Leap days are counted, and can be referred to.
            day: u16,
            /// The default DST transition time is 02:00:00 local time
            time: i32 = 2 * std.time.s_per_hour,
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
            /// The default DST transition time is 02:00:00 local time
            time: i32 = 2 * std.time.s_per_hour,
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
                // TODO : this only seems to make sense for JulianDay rule; otherwise error?
                .JulianDay => |j| return j.day == 365 and j.time >= 24,
                // Since JulianDayZero dates account for leap year, it would vary depending on the year.
                .JulianDayZero => return false,
                // There is also no way to specify "end of the year" with MonthNthWeekDay rules
                .MonthNthWeekDay => return false,
            }
        }

        /// Returned value is the Unix time of the transition in given year,
        /// including the local UTC offset (!)
        pub fn toSecs(rule: Rule, year: u16) i64 {
            const is_leap: bool = cal.isLeapYear(year);
            const start_of_year = cal.dateToRD([3]u16{ year, 1, 1 });

            var t = @as(i64, start_of_year) * std.time.s_per_day;

            switch (rule) {
                .JulianDay => |j| {
                    var x: i64 = j.day;
                    if (x < 60 or !is_leap) x -= 1;
                    t += std.time.s_per_day * x;
                    t += j.time;
                },
                .JulianDayZero => |j| {
                    t += std.time.s_per_day * @as(i64, j.day);
                    t += j.time;
                },
                .MonthNthWeekDay => |mwd| {
                    const DAYS_PER_WEEK = 7;

                    const days_since_epoch: i32 = cal.dateToRD([3]u16{ year, mwd.month, 1 });

                    const first_weekday_of_month = cal.weekdayFromUnixdays(days_since_epoch);

                    const weekday_offset_for_month = if (first_weekday_of_month <= mwd.day)
                        // the first matching weekday is during the first week of the month
                        mwd.day - first_weekday_of_month
                    else
                        // the first matching weekday is during the second week of the month
                        mwd.day + DAYS_PER_WEEK - first_weekday_of_month;

                    const days_since_start_of_month = switch (mwd.n) {
                        1...4 => |n| (n - 1) * DAYS_PER_WEEK + weekday_offset_for_month,
                        5 => if (weekday_offset_for_month + (4 * DAYS_PER_WEEK) >= cal.daysInMonth(mwd.month, is_leap))
                            // the last matching weekday is during the 4th week of the month
                            (4 - 1) * DAYS_PER_WEEK + weekday_offset_for_month
                        else
                            // the last matching weekday is during the 5th week of the month
                            (5 - 1) * DAYS_PER_WEEK + weekday_offset_for_month,
                        else => unreachable,
                    };

                    t += (days_since_epoch - start_of_year) * std.time.s_per_day + std.time.s_per_day * @as(i64, days_since_start_of_month);
                    t += mwd.time;
                },
            }
            return t;
        }

        pub fn format(
            this: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            switch (this) {
                .JulianDay => |julian_day| {
                    try std.fmt.format(writer, "J{}", .{julian_day.day});
                },
                .JulianDayZero => |julian_day_zero| {
                    try std.fmt.format(writer, "{}", .{julian_day_zero.day});
                },
                .MonthNthWeekDay => |month_week_day| {
                    try std.fmt.format(writer, "M{}.{}.{}", .{
                        month_week_day.month,
                        month_week_day.n,
                        month_week_day.day,
                    });
                },
            }

            const time = switch (this) {
                inline else => |rule| rule.time,
            };

            // Only write out the time if it is not the default time of 02:00
            if (time != 2 * std.time.s_per_hour) {
                const seconds = @mod(time, std.time.s_per_min);
                const minutes = @mod(@divTrunc(time, std.time.s_per_min), 60);
                const hours = @divTrunc(@divTrunc(time, std.time.s_per_min), 60);

                try std.fmt.format(writer, "/{}", .{hours});
                if (minutes != 0 or seconds != 0) {
                    try std.fmt.format(writer, ":{}", .{minutes});
                }
                if (seconds != 0) {
                    try std.fmt.format(writer, ":{}", .{seconds});
                }
            }
        }
    };

    /// Get the offset from UTC at given Unix time, including Daylight Saving Time
    // TODO : consider propagating error instead of using 'unreachable'
    pub fn utcOffsetAt(tz: *const Tz, unix_seconds: i64) UTCoffset {
        const dst_designation = tz.dst_designation orelse {
            assert(tz.dst_range == null);
            return UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false) catch unreachable;
        };
        if (tz.dst_range) |range| {
            const ymd = cal.rdToDate(@truncate(@divFloor(unix_seconds, std.time.s_per_day)));
            const year = ymd[0];

            const start_dst = range.start.toSecs(year) - tz.std_offset;
            const end_dst = range.end.toSecs(year) - tz.dst_offset;
            const is_dst_all_year = range.start.isAtStartOfYear() and range.end.isAtEndOfYear();

            if (is_dst_all_year) {
                return UTCoffset.fromSeconds(tz.dst_offset, dst_designation, true) catch unreachable;
            }

            if (start_dst < end_dst) {
                if (unix_seconds >= start_dst and unix_seconds < end_dst) {
                    return UTCoffset.fromSeconds(tz.dst_offset, dst_designation, true) catch unreachable;
                } else {
                    return UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false) catch unreachable;
                }
            } else {
                if (unix_seconds >= end_dst and unix_seconds < start_dst) {
                    return UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false) catch unreachable;
                } else {
                    return UTCoffset.fromSeconds(tz.dst_offset, dst_designation, true) catch unreachable;
                }
            }
        } else {
            return UTCoffset.fromSeconds(tz.std_offset, tz.std_designation, false) catch unreachable;
        }
    }
};

pub fn parsePosixTzString(string: []const u8) !Tz {
    var result = Tz{ .std_designation = undefined, .std_offset = undefined };
    var idx: usize = 0;

    result.std_designation = try parseDesignation(string, &idx);

    // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
    result.std_offset = try parseHHmmss(string[idx..], &idx) * -1;
    if (idx >= string.len) {
        return result;
    }

    if (string[idx] != ',') {
        result.dst_designation = try parseDesignation(string, &idx);

        if (idx < string.len and string[idx] != ',') {
            // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
            result.dst_offset = try parseHHmmss(string[idx..], &idx) * -1;
        } else {
            result.dst_offset = result.std_offset + std.time.s_per_hour;
        }

        if (idx >= string.len) {
            return result;
        }
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
        return error.InvalidFormat;
    }

    return result;
}

fn parseDesignation(string: []const u8, idx: *usize) ![]const u8 {
    const quoted = string[idx.*] == '<';
    if (quoted) idx.* += 1;
    const start = idx.*;
    while (idx.* < string.len) : (idx.* += 1) {
        if ((quoted and string[idx.*] == '>') or
            (!quoted and !std.ascii.isAlphabetic(string[idx.*])))
        {
            const designation = string[start..idx.*];

            // The designation must be at least one character long!
            if (designation.len == 0) return error.InvalidFormat;

            if (quoted) idx.* += 1;
            return designation;
        }
    }
    return error.InvalidFormat;
}

fn parseRule(_string: []const u8) !Tz.Rule {
    var string = _string;
    if (string.len < 2) return error.InvalidFormat;

    const time: i32 = if (std.mem.indexOf(u8, string, "/")) |start_of_time| parse_time: {
        const time_string = string[start_of_time + 1 ..];

        var i: usize = 0;
        const time = try parseHHmmss(time_string, &i);

        // The time at the end of the rule should be the last thing in the string. Fixes the parsing to return
        // an error in cases like "/2/3", where they have some extra characters.
        if (i != time_string.len) {
            return error.InvalidFormat;
        }

        string = string[0..start_of_time];

        break :parse_time time;
    } else 2 * std.time.s_per_hour;

    if (string[0] == 'J') {
        const julian_day1 = std.fmt.parseInt(u16, string[1..], 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };

        if (julian_day1 < 1 or julian_day1 > 365) return error.InvalidFormat;
        return Tz.Rule{ .JulianDay = .{ .day = julian_day1, .time = time } };
    } else if (std.ascii.isDigit(string[0])) {
        const julian_day0 = std.fmt.parseInt(u16, string[0..], 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };

        if (julian_day0 > 365) return error.InvalidFormat;
        return Tz.Rule{ .JulianDayZero = .{ .day = julian_day0, .time = time } };
    } else if (string[0] == 'M') {
        var split_iter = std.mem.splitScalar(u8, string[1..], '.');
        const m_str = split_iter.next() orelse return error.InvalidFormat;
        const n_str = split_iter.next() orelse return error.InvalidFormat;
        const d_str = split_iter.next() orelse return error.InvalidFormat;

        const m = std.fmt.parseInt(u8, m_str, 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };
        const n = std.fmt.parseInt(u8, n_str, 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };
        const d = std.fmt.parseInt(u8, d_str, 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };

        if (m < 1 or m > 12) return error.InvalidFormat;
        if (n < 1 or n > 5) return error.InvalidFormat;
        if (d > 6) return error.InvalidFormat;

        return Tz.Rule{ .MonthNthWeekDay = .{ .month = m, .n = n, .day = d, .time = time } };
    } else {
        return error.InvalidFormat;
    }
}

/// Parses hh[:mm[:ss]] to a number of seconds. Hours may be one digit long. Minutes and seconds must be two digits.
fn parseHHmmss(string: []const u8, idx_ptr: *usize) !i32 {
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
    const hour_string = segment_iter.next() orelse return error.EmptyString;
    const hours = std.fmt.parseInt(u32, hour_string, 10) catch |err| switch (err) {
        error.InvalidCharacter => return error.InvalidFormat,
        error.Overflow => return error.InvalidFormat,
    };
    if (hours > 167) {
        return error.InvalidFormat;
    }
    result += std.time.s_per_hour * @as(i32, @intCast(hours));

    if (segment_iter.next()) |minute_string| {
        if (minute_string.len != 2) {
            return error.InvalidFormat;
        }
        const minutes = try std.fmt.parseInt(u32, minute_string, 10);
        if (minutes > 59) return error.InvalidFormat;
        result += std.time.s_per_min * @as(i32, @intCast(minutes));
    }

    if (segment_iter.next()) |second_string| {
        if (second_string.len != 2) {
            return error.InvalidFormat;
        }
        const seconds = try std.fmt.parseInt(u8, second_string, 10);
        if (seconds > 59) return error.InvalidFormat;
        result += seconds;
    }

    return result * sign;
}
