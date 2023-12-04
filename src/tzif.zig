const std = @import("std");
const testing = std.testing;

const log = std.log.scoped(.tzif);

pub const TimeZone = struct {
    allocator: std.mem.Allocator,
    version: Version,
    transitionTimes: []i64,
    transitionTypes: []u8,
    localTimeTypes: []LocalTimeType,
    designations: []u8,
    leapSeconds: []LeapSecond,
    transitionIsStd: []bool,
    transitionIsUT: []bool,
    string: []u8,
    posixTZ: ?PosixTZ,

    pub fn deinit(this: @This()) void {
        this.allocator.free(this.transitionTimes);
        this.allocator.free(this.transitionTypes);
        this.allocator.free(this.localTimeTypes);
        this.allocator.free(this.designations);
        this.allocator.free(this.leapSeconds);
        this.allocator.free(this.transitionIsStd);
        this.allocator.free(this.transitionIsUT);
        this.allocator.free(this.string);
    }

    pub const ConversionResult = struct {
        timestamp: i64,
        offset: i32,
        is_daylight_saving_time: bool,
        designation: []const u8,
    };

    pub fn localTimeFromUTC(this: @This(), utc: i64) ?ConversionResult {
        const transition_type_by_timestamp = getTransitionTypeByTimestamp(this.transitionTimes, utc);
        switch (transition_type_by_timestamp) {
            .first_local_time_type => {
                const local_time_type = this.localTimeTypes[0];

                var designation = this.designations[local_time_type.designation_index .. this.designations.len - 1];
                for (designation, 0..) |c, i| {
                    if (c == 0) {
                        designation = designation[0..i];
                        break;
                    }
                }

                return ConversionResult{
                    .timestamp = utc + local_time_type.ut_offset,
                    .offset = local_time_type.ut_offset,
                    .is_daylight_saving_time = local_time_type.is_daylight_saving_time,
                    .designation = designation,
                };
            },
            .transition_index => |transition_index| {
                const local_time_type_idx = this.transitionTypes[transition_index];
                const local_time_type = this.localTimeTypes[local_time_type_idx];

                var designation = this.designations[local_time_type.designation_index .. this.designations.len - 1];
                for (designation, 0..) |c, i| {
                    if (c == 0) {
                        designation = designation[0..i];
                        break;
                    }
                }

                return ConversionResult{
                    .timestamp = utc + local_time_type.ut_offset,
                    .offset = local_time_type.ut_offset,
                    .is_daylight_saving_time = local_time_type.is_daylight_saving_time,
                    .designation = designation,
                };
            },
            .specified_by_posix_tz,
            .specified_by_posix_tz_or_index_0,
            => if (this.posixTZ) |posixTZ| {
                // Base offset on the TZ string
                const offset_res = posixTZ.offset(utc);
                return ConversionResult{
                    .timestamp = utc + offset_res.offset,
                    .offset = offset_res.offset,
                    .is_daylight_saving_time = offset_res.is_daylight_saving_time,
                    .designation = offset_res.designation,
                };
            } else {
                switch (transition_type_by_timestamp) {
                    .specified_by_posix_tz => return null,
                    .specified_by_posix_tz_or_index_0 => {
                        const local_time_type = this.localTimeTypes[0];

                        var designation = this.designations[local_time_type.designation_index .. this.designations.len - 1];
                        for (designation, 0..) |c, i| {
                            if (c == 0) {
                                designation = designation[0..i];
                                break;
                            }
                        }

                        return ConversionResult{
                            .timestamp = utc + local_time_type.ut_offset,
                            .offset = local_time_type.ut_offset,
                            .is_daylight_saving_time = local_time_type.is_daylight_saving_time,
                            .designation = designation,
                        };
                    },
                    else => unreachable,
                }
            },
        }
    }
};

pub const Version = enum(u8) {
    V1 = 0,
    V2 = '2',
    V3 = '3',

    pub fn timeSize(this: @This()) u32 {
        return switch (this) {
            .V1 => 4,
            .V2, .V3 => 8,
        };
    }

    pub fn leapSize(this: @This()) u32 {
        return this.timeSize() + 4;
    }

    pub fn string(this: @This()) []const u8 {
        return switch (this) {
            .V1 => "1",
            .V2 => "2",
            .V3 => "3",
        };
    }
};

pub const LocalTimeType = struct {
    /// An i32 specifying the number of seconds to be added to UT in order to determine local time.
    /// The value MUST NOT be -2**31 and SHOULD be in the range
    /// [-89999, 93599] (i.e., its value SHOULD be more than -25 hours
    /// and less than 26 hours).  Avoiding -2**31 allows 32-bit clients
    /// to negate the value without overflow.  Restricting it to
    /// [-89999, 93599] allows easy support by implementations that
    /// already support the POSIX-required range [-24:59:59, 25:59:59].
    ut_offset: i32,

    /// A value indicating whether local time should be considered Daylight Saving Time (DST).
    ///
    /// A value of `true` indicates that this type of time is DST.
    /// A value of `false` indicates that this time type is standard time.
    is_daylight_saving_time: bool,

    /// A u8 specifying an index into the time zone designations, thereby
    /// selecting a particular designation string. Each index MUST be
    /// in the range [0, "charcnt" - 1]; it designates the
    /// NUL-terminated string of octets starting at position `designation_index` in
    /// the time zone designations.  (This string MAY be empty.)  A NUL
    /// octet MUST exist in the time zone designations at or after
    /// position `designation_index`.
    designation_index: u8,
};

pub const LeapSecond = struct {
    occur: i64,
    corr: i32,
};

/// This is based on Posix definition of the TZ environment variable
pub const PosixTZ = struct {
    std_designation: []const u8,
    std_offset: i32,
    dst_designation: ?[]const u8 = null,
    /// This field is ignored when dst is null
    dst_offset: i32 = 0,
    dst_range: ?struct {
        start: Rule,
        end: Rule,
    } = null,

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

        pub fn isAtStartOfYear(this: @This()) bool {
            switch (this) {
                .JulianDay => |j| return j.day == 1 and j.time == 0,
                .JulianDayZero => |j| return j.day == 0 and j.time == 0,
                .MonthNthWeekDay => |mwd| return mwd.month == 1 and mwd.n == 1 and mwd.day == 0 and mwd.time == 0,
            }
        }

        pub fn isAtEndOfYear(this: @This()) bool {
            switch (this) {
                .JulianDay => |j| return j.day == 365 and j.time >= 24,
                // Since JulianDayZero dates account for leap year, it would vary depending on the year.
                .JulianDayZero => return false,
                // There is also no way to specify "end of the year" with MonthNthWeekDay rules
                .MonthNthWeekDay => return false,
            }
        }

        /// Returned value is the local timestamp when the timezone will transition in the given year.
        pub fn toSecs(this: @This(), year: i32) i64 {
            const is_leap: bool = isLeapYear(year);
            const start_of_year = year_to_secs(year);

            var t = start_of_year;

            switch (this) {
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
                    const offset_of_month_in_year = month_to_secs(mwd.month - 1, is_leap);

                    const UNIX_EPOCH_WEEKDAY = 4; // Thursday
                    const DAYS_PER_WEEK = 7;

                    const days_since_epoch = @divFloor(start_of_year + offset_of_month_in_year, std.time.s_per_day);

                    const first_weekday_of_month = @mod(days_since_epoch + UNIX_EPOCH_WEEKDAY, DAYS_PER_WEEK);

                    const weekday_offset_for_month = if (first_weekday_of_month <= mwd.day)
                        // the first matching weekday is during the first week of the month
                        mwd.day - first_weekday_of_month
                    else
                        // the first matching weekday is during the second week of the month
                        mwd.day + DAYS_PER_WEEK - first_weekday_of_month;

                    const days_since_start_of_month = switch (mwd.n) {
                        1...4 => |n| (n - 1) * DAYS_PER_WEEK + weekday_offset_for_month,
                        5 => if (weekday_offset_for_month + (4 * DAYS_PER_WEEK) >= days_in_month(mwd.month, is_leap))
                            // the last matching weekday is during the 4th week of the month
                            (4 - 1) * DAYS_PER_WEEK + weekday_offset_for_month
                        else
                            // the last matching weekday is during the 5th week of the month
                            (5 - 1) * DAYS_PER_WEEK + weekday_offset_for_month,
                        else => unreachable,
                    };

                    t += offset_of_month_in_year + std.time.s_per_day * days_since_start_of_month;
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

    pub const OffsetResult = struct {
        offset: i32,
        designation: []const u8,
        is_daylight_saving_time: bool,
    };

    /// Get the offset from UTC for this PosixTZ, factoring in Daylight Saving Time.
    pub fn offset(this: @This(), utc: i64) OffsetResult {
        const dst_designation = this.dst_designation orelse {
            std.debug.assert(this.dst_range == null);
            return .{ .offset = this.std_offset, .designation = this.std_designation, .is_daylight_saving_time = false };
        };
        if (this.dst_range) |range| {
            const utc_year = secs_to_year(utc);
            const start_dst = range.start.toSecs(utc_year) - this.std_offset;
            const end_dst = range.end.toSecs(utc_year) - this.dst_offset;

            const is_dst_all_year = range.start.isAtStartOfYear() and range.end.isAtEndOfYear();
            if (is_dst_all_year) {
                return .{ .offset = this.dst_offset, .designation = dst_designation, .is_daylight_saving_time = true };
            }

            if (start_dst < end_dst) {
                if (utc >= start_dst and utc < end_dst) {
                    return .{ .offset = this.dst_offset, .designation = dst_designation, .is_daylight_saving_time = true };
                } else {
                    return .{ .offset = this.std_offset, .designation = this.std_designation, .is_daylight_saving_time = false };
                }
            } else {
                if (utc >= end_dst and utc < start_dst) {
                    return .{ .offset = this.dst_offset, .designation = dst_designation, .is_daylight_saving_time = true };
                } else {
                    return .{ .offset = this.std_offset, .designation = this.std_designation, .is_daylight_saving_time = false };
                }
            }
        } else {
            return .{ .offset = this.std_offset, .designation = this.std_designation, .is_daylight_saving_time = false };
        }
    }

    pub fn format(
        this: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const should_quote_std_designation = for (this.std_designation) |character| {
            if (!std.ascii.isAlphabetic(character)) {
                break true;
            }
        } else false;

        if (should_quote_std_designation) {
            try writer.writeAll("<");
            try writer.writeAll(this.std_designation);
            try writer.writeAll(">");
        } else {
            try writer.writeAll(this.std_designation);
        }

        const std_offset_west = -this.std_offset;
        const std_seconds = @rem(std_offset_west, std.time.s_per_min);
        const std_minutes = @rem(@divTrunc(std_offset_west, std.time.s_per_min), 60);
        const std_hours = @divTrunc(@divTrunc(std_offset_west, std.time.s_per_min), 60);

        try std.fmt.format(writer, "{}", .{std_hours});
        if (std_minutes != 0 or std_seconds != 0) {
            try std.fmt.format(writer, ":{}", .{if (std_minutes < 0) -std_minutes else std_minutes});
        }
        if (std_seconds != 0) {
            try std.fmt.format(writer, ":{}", .{if (std_seconds < 0) -std_seconds else std_seconds});
        }

        if (this.dst_designation) |dst_designation| {
            const should_quote_dst_designation = for (dst_designation) |character| {
                if (!std.ascii.isAlphabetic(character)) {
                    break true;
                }
            } else false;

            if (should_quote_dst_designation) {
                try writer.writeAll("<");
                try writer.writeAll(dst_designation);
                try writer.writeAll(">");
            } else {
                try writer.writeAll(dst_designation);
            }

            // Only write out the DST offset if it is not just the standard offset plus an hour
            if (this.dst_offset != this.std_offset + std.time.s_per_hour) {
                const dst_offset_west = -this.dst_offset;
                const dst_seconds = @rem(dst_offset_west, std.time.s_per_min);
                const dst_minutes = @rem(@divTrunc(dst_offset_west, std.time.s_per_min), 60);
                const dst_hours = @divTrunc(@divTrunc(dst_offset_west, std.time.s_per_min), 60);

                try std.fmt.format(writer, "{}", .{dst_hours});
                if (dst_minutes != 0 or dst_seconds != 0) {
                    try std.fmt.format(writer, ":{}", .{if (dst_minutes < 0) -dst_minutes else dst_minutes});
                }
                if (dst_seconds != 0) {
                    try std.fmt.format(writer, ":{}", .{if (dst_seconds < 0) -dst_seconds else dst_seconds});
                }
            }
        }

        if (this.dst_range) |dst_range| {
            try std.fmt.format(writer, ",{},{}", .{ dst_range.start, dst_range.end });
        }
    }

    test format {
        const america_denver = PosixTZ{
            .std_designation = "MST",
            .std_offset = -25200,
            .dst_designation = "MDT",
            .dst_offset = -21600,
            .dst_range = .{
                .start = .{
                    .MonthNthWeekDay = .{
                        .month = 3,
                        .n = 2,
                        .day = 0,
                        .time = 2 * std.time.s_per_hour,
                    },
                },
                .end = .{
                    .MonthNthWeekDay = .{
                        .month = 11,
                        .n = 1,
                        .day = 0,
                        .time = 2 * std.time.s_per_hour,
                    },
                },
            },
        };

        try std.testing.expectFmt("MST7MDT,M3.2.0,M11.1.0", "{}", .{america_denver});

        const europe_berlin = PosixTZ{
            .std_designation = "CET",
            .std_offset = 3600,
            .dst_designation = "CEST",
            .dst_offset = 7200,
            .dst_range = .{
                .start = .{
                    .MonthNthWeekDay = .{
                        .month = 3,
                        .n = 5,
                        .day = 0,
                        .time = 2 * std.time.s_per_hour,
                    },
                },
                .end = .{
                    .MonthNthWeekDay = .{
                        .month = 10,
                        .n = 5,
                        .day = 0,
                        .time = 3 * std.time.s_per_hour,
                    },
                },
            },
        };
        try std.testing.expectFmt("CET-1CEST,M3.5.0,M10.5.0/3", "{}", .{europe_berlin});

        const antarctica_syowa = PosixTZ{
            .std_designation = "+03",
            .std_offset = 3 * std.time.s_per_hour,
            .dst_designation = null,
            .dst_offset = undefined,
            .dst_range = null,
        };
        try std.testing.expectFmt("<+03>-3", "{}", .{antarctica_syowa});

        const pacific_chatham = PosixTZ{
            .std_designation = "+1245",
            .std_offset = 12 * std.time.s_per_hour + 45 * std.time.s_per_min,
            .dst_designation = "+1345",
            .dst_offset = 13 * std.time.s_per_hour + 45 * std.time.s_per_min,
            .dst_range = .{
                .start = .{
                    .MonthNthWeekDay = .{
                        .month = 9,
                        .n = 5,
                        .day = 0,
                        .time = 2 * std.time.s_per_hour + 45 * std.time.s_per_min,
                    },
                },
                .end = .{
                    .MonthNthWeekDay = .{
                        .month = 4,
                        .n = 1,
                        .day = 0,
                        .time = 3 * std.time.s_per_hour + 45 * std.time.s_per_min,
                    },
                },
            },
        };
        try std.testing.expectFmt("<+1245>-12:45<+1345>,M9.5.0/2:45,M4.1.0/3:45", "{}", .{pacific_chatham});
    }
};

fn days_in_month(m: u8, is_leap: bool) i32 {
    if (m == 2) {
        return 28 + @as(i32, @intFromBool(is_leap));
    } else {
        return 30 + ((@as(i32, 0xad5) >> @as(u5, @intCast(m - 1))) & 1);
    }
}

fn month_to_secs(m: u8, is_leap: bool) i32 {
    const d = std.time.s_per_day;
    const secs_though_month = [12]i32{
        0 * d,   31 * d,  59 * d,  90 * d,
        120 * d, 151 * d, 181 * d, 212 * d,
        243 * d, 273 * d, 304 * d, 334 * d,
    };
    var t = secs_though_month[m];
    if (is_leap and m >= 2) t += d;
    return t;
}

fn secs_to_year(secs: i64) i32 {
    // Copied from MUSL
    // TODO: make more efficient?
    var y = @as(i32, @intCast(@divFloor(secs, std.time.s_per_day * 365) + 1970));
    while (year_to_secs(y) > secs) y -= 1;
    while (year_to_secs(y + 1) < secs) y += 1;
    return y;
}

test secs_to_year {
    try std.testing.expectEqual(@as(i32, 1970), secs_to_year(0));
    try std.testing.expectEqual(@as(i32, 2023), secs_to_year(1672531200));
}

fn isLeapYear(year: i32) bool {
    return @mod(year, 4) == 0 and (@mod(year, 100) != 0 or @mod(year, 400) == 0);
}

test isLeapYear {
    const leap_years_1800_to_2400 = [_]i32{
        1804, 1808, 1812, 1816, 1820, 1824, 1828,
        1832, 1836, 1840, 1844, 1848, 1852, 1856,
        1860, 1864, 1868, 1872, 1876, 1880, 1884,
        1888, 1892, 1896, 1904, 1908, 1912, 1916,
        1920, 1924, 1928, 1932, 1936, 1940, 1944,
        1948, 1952, 1956, 1960, 1964, 1968, 1972,
        1976, 1980, 1984, 1988, 1992, 1996, 2000,
        2004, 2008, 2012, 2016, 2020, 2024, 2028,
        2032, 2036, 2040, 2044, 2048, 2052, 2056,
        2060, 2064, 2068, 2072, 2076, 2080, 2084,
        2088, 2092, 2096, 2104, 2108, 2112, 2116,
        2120, 2124, 2128, 2132, 2136, 2140, 2144,
        2148, 2152, 2156, 2160, 2164, 2168, 2172,
        2176, 2180, 2184, 2188, 2192, 2196, 2204,
        2208, 2212, 2216, 2220, 2224, 2228, 2232,
        2236, 2240, 2244, 2248, 2252, 2256, 2260,
        2264, 2268, 2272, 2276, 2280, 2284, 2288,
        2292, 2296, 2304, 2308, 2312, 2316, 2320,
        2324, 2328, 2332, 2336, 2340, 2344, 2348,
        2352, 2356, 2360, 2364, 2368, 2372, 2376,
        2380, 2384, 2388, 2392, 2396, 2400,
    };

    for (leap_years_1800_to_2400) |leap_year| {
        errdefer std.debug.print("year = {}\n", .{leap_year});
        try std.testing.expect(isLeapYear(leap_year));
    }
    try std.testing.expect(!isLeapYear(2021));
    try std.testing.expect(!isLeapYear(2023));
}

const UNIX_EPOCH_YEAR = 1970;
const UNIX_EPOCH_NUMBER_OF_4_YEAR_PERIODS = UNIX_EPOCH_YEAR / 4;
const UNIX_EPOCH_CENTURIES = UNIX_EPOCH_YEAR / 100;
/// Number of 400 year periods before the unix epoch
const UNIX_EPOCH_CYCLES = UNIX_EPOCH_YEAR / 400;

/// Takes in year number, returns the unix timestamp for the start of the year.
fn year_to_secs(year: i32) i64 {
    const number_of_four_year_periods = @divFloor(year - 1, 4);
    const centuries = @divFloor(year - 1, 100);
    const cycles = @divFloor(year - 1, 400);

    const years_since_epoch = year - UNIX_EPOCH_YEAR;
    const number_of_four_year_periods_since_epoch = number_of_four_year_periods - UNIX_EPOCH_NUMBER_OF_4_YEAR_PERIODS;
    const centuries_since_epoch = centuries - UNIX_EPOCH_CENTURIES;
    const cycles_since_epoch = cycles - UNIX_EPOCH_CYCLES;

    const number_of_leap_days_since_epoch =
        number_of_four_year_periods_since_epoch -
        centuries_since_epoch +
        cycles_since_epoch;

    const SECONDS_PER_REGULAR_YEAR = 365 * std.time.s_per_day;
    return years_since_epoch * SECONDS_PER_REGULAR_YEAR + number_of_leap_days_since_epoch * std.time.s_per_day;
}

test year_to_secs {
    try std.testing.expectEqual(@as(i64, 0), year_to_secs(1970));
    try std.testing.expectEqual(@as(i64, 1577836800), year_to_secs(2020));
    try std.testing.expectEqual(@as(i64, 1609459200), year_to_secs(2021));
    try std.testing.expectEqual(@as(i64, 1640995200), year_to_secs(2022));
    try std.testing.expectEqual(@as(i64, 1672531200), year_to_secs(2023));
}

const TIME_TYPE_SIZE = 6;

pub const TZifHeader = struct {
    version: Version,
    isutcnt: u32,
    isstdcnt: u32,
    leapcnt: u32,
    timecnt: u32,
    typecnt: u32,
    charcnt: u32,

    pub fn dataSize(this: @This(), dataBlockVersion: Version) u32 {
        return this.timecnt * dataBlockVersion.timeSize() +
            this.timecnt +
            this.typecnt * TIME_TYPE_SIZE +
            this.charcnt +
            this.leapcnt * dataBlockVersion.leapSize() +
            this.isstdcnt +
            this.isutcnt;
    }
};

pub fn parseHeader(reader: anytype, seekableStream: anytype) !TZifHeader {
    var magic_buf: [4]u8 = undefined;
    try reader.readNoEof(&magic_buf);
    if (!std.mem.eql(u8, "TZif", &magic_buf)) {
        return error.InvalidFormat; // Magic number "TZif" is missing
    }

    // Check verison
    const version = reader.readEnum(Version, .Little) catch |err| switch (err) {
        error.InvalidValue => return error.UnsupportedVersion,
        else => |e| return e,
    };
    if (version == .V1) {
        return error.UnsupportedVersion;
    }

    // Seek past reserved bytes
    try seekableStream.seekBy(15);

    return TZifHeader{
        .version = version,
        .isutcnt = try reader.readInt(u32, .Big),
        .isstdcnt = try reader.readInt(u32, .Big),
        .leapcnt = try reader.readInt(u32, .Big),
        .timecnt = try reader.readInt(u32, .Big),
        .typecnt = try reader.readInt(u32, .Big),
        .charcnt = try reader.readInt(u32, .Big),
    };
}

/// Parses hh[:mm[:ss]] to a number of seconds. Hours may be one digit long. Minutes and seconds must be two digits.
fn hhmmss_offset_to_s(_string: []const u8, idx: *usize) !i32 {
    var string = _string;
    var sign: i2 = 1;
    if (string[0] == '+') {
        sign = 1;
        string = string[1..];
        idx.* += 1;
    } else if (string[0] == '-') {
        sign = -1;
        string = string[1..];
        idx.* += 1;
    }

    for (string, 0..) |c, i| {
        if (!(std.ascii.isDigit(c) or c == ':')) {
            string = string[0..i];
            break;
        }
        idx.* += 1;
    }

    var result: i32 = 0;

    var segment_iter = std.mem.split(u8, string, ":");
    const hour_string = segment_iter.next() orelse return error.EmptyString;
    const hours = std.fmt.parseInt(u32, hour_string, 10) catch |err| switch (err) {
        error.InvalidCharacter => return error.InvalidFormat,
        error.Overflow => return error.InvalidFormat,
    };
    if (hours > 167) {
        // TODO: use diagnostics mechanism instead of logging
        log.warn("too many hours! {}", .{hours});
        return error.InvalidFormat;
    }
    result += std.time.s_per_hour * @as(i32, @intCast(hours));

    if (segment_iter.next()) |minute_string| {
        if (minute_string.len != 2) {
            // TODO: Add diagnostics when returning an error.
            return error.InvalidFormat;
        }
        const minutes = try std.fmt.parseInt(u32, minute_string, 10);
        if (minutes > 59) return error.InvalidFormat;
        result += std.time.s_per_min * @as(i32, @intCast(minutes));
    }

    if (segment_iter.next()) |second_string| {
        if (second_string.len != 2) {
            // TODO: Add diagnostics when returning an error.
            return error.InvalidFormat;
        }
        const seconds = try std.fmt.parseInt(u8, second_string, 10);
        if (seconds > 59) return error.InvalidFormat;
        result += seconds;
    }

    return result * sign;
}

fn parsePosixTZ_rule(_string: []const u8) !PosixTZ.Rule {
    var string = _string;
    if (string.len < 2) return error.InvalidFormat;

    const time: i32 = if (std.mem.indexOf(u8, string, "/")) |start_of_time| parse_time: {
        const time_string = string[start_of_time + 1 ..];

        var i: usize = 0;
        const time = try hhmmss_offset_to_s(time_string, &i);

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
        return PosixTZ.Rule{ .JulianDay = .{ .day = julian_day1, .time = time } };
    } else if (std.ascii.isDigit(string[0])) {
        const julian_day0 = std.fmt.parseInt(u16, string[0..], 10) catch |err| switch (err) {
            error.InvalidCharacter => return error.InvalidFormat,
            error.Overflow => return error.InvalidFormat,
        };

        if (julian_day0 > 365) return error.InvalidFormat;
        return PosixTZ.Rule{ .JulianDayZero = .{ .day = julian_day0, .time = time } };
    } else if (string[0] == 'M') {
        var split_iter = std.mem.split(u8, string[1..], ".");
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

        return PosixTZ.Rule{ .MonthNthWeekDay = .{ .month = m, .n = n, .day = d, .time = time } };
    } else {
        return error.InvalidFormat;
    }
}

fn parsePosixTZ_designation(string: []const u8, idx: *usize) ![]const u8 {
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

pub fn parsePosixTZ(string: []const u8) !PosixTZ {
    var result = PosixTZ{ .std_designation = undefined, .std_offset = undefined };
    var idx: usize = 0;

    result.std_designation = try parsePosixTZ_designation(string, &idx);

    // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
    result.std_offset = try hhmmss_offset_to_s(string[idx..], &idx) * -1;
    if (idx >= string.len) {
        return result;
    }

    if (string[idx] != ',') {
        result.dst_designation = try parsePosixTZ_designation(string, &idx);

        if (idx < string.len and string[idx] != ',') {
            // multiply by -1 to get offset as seconds East of Greenwich as TZif specifies it:
            result.dst_offset = try hhmmss_offset_to_s(string[idx..], &idx) * -1;
        } else {
            result.dst_offset = result.std_offset + std.time.s_per_hour;
        }

        if (idx >= string.len) {
            return result;
        }
    }

    std.debug.assert(string[idx] == ',');
    idx += 1;

    if (std.mem.indexOf(u8, string[idx..], ",")) |_end_of_start_rule| {
        const end_of_start_rule = idx + _end_of_start_rule;
        result.dst_range = .{
            .start = try parsePosixTZ_rule(string[idx..end_of_start_rule]),
            .end = try parsePosixTZ_rule(string[end_of_start_rule + 1 ..]),
        };
    } else {
        return error.InvalidFormat;
    }

    return result;
}

pub fn parse(allocator: std.mem.Allocator, reader: anytype, seekableStream: anytype) !TimeZone {
    const v1_header = try parseHeader(reader, seekableStream);
    try seekableStream.seekBy(v1_header.dataSize(.V1));

    const v2_header = try parseHeader(reader, seekableStream);

    // Parse transition times
    var transition_times = try allocator.alloc(i64, v2_header.timecnt);
    errdefer allocator.free(transition_times);
    {
        var prev: i64 = -(2 << 59); // Earliest time supported, this is earlier than the big bang
        var i: usize = 0;
        while (i < transition_times.len) : (i += 1) {
            transition_times[i] = try reader.readInt(i64, .Big);
            if (transition_times[i] <= prev) {
                return error.InvalidFormat;
            }
            prev = transition_times[i];
        }
    }

    // Parse transition types
    const transition_types = try allocator.alloc(u8, v2_header.timecnt);
    errdefer allocator.free(transition_types);
    try reader.readNoEof(transition_types);
    for (transition_types) |transition_type| {
        if (transition_type >= v2_header.typecnt) {
            return error.InvalidFormat; // a transition type index is out of bounds
        }
    }

    // Parse local time type records
    var local_time_types = try allocator.alloc(LocalTimeType, v2_header.typecnt);
    errdefer allocator.free(local_time_types);
    {
        var i: usize = 0;
        while (i < local_time_types.len) : (i += 1) {
            local_time_types[i].ut_offset = try reader.readInt(i32, .Big);
            local_time_types[i].is_daylight_saving_time = switch (try reader.readByte()) {
                0 => false,
                1 => true,
                else => return error.InvalidFormat,
            };

            local_time_types[i].designation_index = try reader.readByte();
            if (local_time_types[i].designation_index >= v2_header.charcnt) {
                return error.InvalidFormat;
            }
        }
    }

    // Read designations
    const time_zone_designations = try allocator.alloc(u8, v2_header.charcnt);
    errdefer allocator.free(time_zone_designations);
    try reader.readNoEof(time_zone_designations);

    // Parse leap seconds records
    var leap_seconds = try allocator.alloc(LeapSecond, v2_header.leapcnt);
    errdefer allocator.free(leap_seconds);
    {
        var i: usize = 0;
        while (i < leap_seconds.len) : (i += 1) {
            leap_seconds[i].occur = try reader.readInt(i64, .Big);
            if (i == 0 and leap_seconds[i].occur < 0) {
                return error.InvalidFormat;
            } else if (i != 0 and leap_seconds[i].occur - leap_seconds[i - 1].occur < 2419199) {
                return error.InvalidFormat; // There must be at least 28 days worth of seconds between leap seconds
            }

            leap_seconds[i].corr = try reader.readInt(i32, .Big);
            if (i == 0 and (leap_seconds[0].corr != 1 and leap_seconds[0].corr != -1)) {
                log.warn("First leap second correction is not 1 or -1: {}", .{leap_seconds[0]});
                return error.InvalidFormat;
            } else if (i != 0) {
                const diff = leap_seconds[i].corr - leap_seconds[i - 1].corr;
                if (diff != 1 and diff != -1) {
                    log.warn("Too large of a difference between leap seconds: {}", .{diff});
                    return error.InvalidFormat;
                }
            }
        }
    }

    // Parse standard/wall indicators
    var transition_is_std = try allocator.alloc(bool, v2_header.isstdcnt);
    errdefer allocator.free(transition_is_std);
    {
        var i: usize = 0;
        while (i < transition_is_std.len) : (i += 1) {
            transition_is_std[i] = switch (try reader.readByte()) {
                1 => true,
                0 => false,
                else => return error.InvalidFormat,
            };
        }
    }

    // Parse UT/local indicators
    var transition_is_ut = try allocator.alloc(bool, v2_header.isutcnt);
    errdefer allocator.free(transition_is_ut);
    {
        var i: usize = 0;
        while (i < transition_is_ut.len) : (i += 1) {
            transition_is_ut[i] = switch (try reader.readByte()) {
                1 => true,
                0 => false,
                else => return error.InvalidFormat,
            };
        }
    }

    // Parse TZ string from footer
    if ((try reader.readByte()) != '\n') return error.InvalidFormat;
    const tz_string = try reader.readUntilDelimiterAlloc(allocator, '\n', 60);
    errdefer allocator.free(tz_string);

    const posixTZ: ?PosixTZ = if (tz_string.len > 0)
        try parsePosixTZ(tz_string)
    else
        null;

    return TimeZone{
        .allocator = allocator,
        .version = v2_header.version,
        .transitionTimes = transition_times,
        .transitionTypes = transition_types,
        .localTimeTypes = local_time_types,
        .designations = time_zone_designations,
        .leapSeconds = leap_seconds,
        .transitionIsStd = transition_is_std,
        .transitionIsUT = transition_is_ut,
        .string = tz_string,
        .posixTZ = posixTZ,
    };
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !TimeZone {
    const cwd = std.fs.cwd();

    const file = try cwd.openFile(path, .{});
    defer file.close();

    return parse(allocator, file.reader(), file.seekableStream());
}

const TransitionType = union(enum) {
    first_local_time_type,
    transition_index: usize,
    specified_by_posix_tz,
    specified_by_posix_tz_or_index_0,
};

/// Get the transition type of the first element in the `transition_times` array which is less than or equal to `timestamp_utc`.
///
/// Returns `.transition_index` if the timestamp is contained inside the `transition_times` array.
///
/// Returns `.specified_by_posix_tz_or_index_0` if the `transition_times` list is empty.
///
/// Returns `.first_local_time_type` if `timestamp_utc` is before the first transition time.
///
/// Returns `.specified_by_posix_tz` if `timestamp_utc` is after or on the last transition time.
fn getTransitionTypeByTimestamp(transition_times: []const i64, timestamp_utc: i64) TransitionType {
    if (transition_times.len == 0) return .specified_by_posix_tz_or_index_0;
    if (timestamp_utc < transition_times[0]) return .first_local_time_type;
    if (timestamp_utc >= transition_times[transition_times.len - 1]) return .specified_by_posix_tz;

    var left: usize = 0;
    var right: usize = transition_times.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        if (transition_times[mid] == timestamp_utc) {
            if (mid + 1 < transition_times.len) {
                return .{ .transition_index = mid };
            } else {
                return .{ .transition_index = mid };
            }
        } else if (transition_times[mid] > timestamp_utc) {
            right = mid;
        } else if (transition_times[mid] < timestamp_utc) {
            left = mid + 1;
        }
    }

    if (right >= transition_times.len) {
        return .specified_by_posix_tz;
    } else if (right > 0) {
        return .{ .transition_index = right - 1 };
    } else {
        return .first_local_time_type;
    }
}
