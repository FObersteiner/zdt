//! calendric stuff
const std = @import("std");
const Datetime = @import("./Datetime.zig");

/// Days per month, depending on if it comes from a leap year.
/// Based on Neri/Schneider's "Euclidean affine functions"
pub fn daysInMonth(m: u5, is_leap: bool) u5 {
    std.debug.assert((m > 0) and (m < 13));
    if (m == 2) return if (is_leap) 29 else 28;
    return 30 | (m ^ (m >> 3));
}

/// Number of days in a certain month of any year.
pub fn lastDayOfMonth(year: u16, month: u5) u5 {
    return daysInMonth(month, isLeapYear(year));
}

/// Calculate the day of the week (Sun = 0, Sat = 6) for given days after Unix epoch
pub fn weekdayFromUnixdays(unix_days: i32) u3 {
    // offset by +4 since Unix epoch falls on a Thursday
    // since @mod always returns a positive value, we do not have to treat negative unix_days separately
    return @intCast(@mod((unix_days + 4), 7));
}

/// Calculate the ISO day of the week (Mon = 1, Sun = 7) for given days after Unix epoch
pub fn ISOweekdayFromUnixdays(unix_days: i32) u3 {
    return @intCast(@mod((unix_days + 3), 7) + 1);
}

/// Test if a month is a leap month, i.e. Feb in a leap year.
pub fn isLeapMonth(year: u16, month: u4) bool {
    return isLeapYear(year) and month == 2;
}

/// Difference between weekdays; x-y. x and y both <= 6 and >= 0, result in range [0..6].
pub fn weekdayDifference(x: u3, y: u3) i4 {
    std.debug.assert((x >= 0) and (x <= 6));
    std.debug.assert((y >= 0) and (y <= 6));
    const z: i4 = @as(i4, x) - @as(i4, y);
    if (z <= 6) return z;
    return z + 7;
}

/// Calculate the day of the year. Result is [1, 366].
/// See also https://astronomy.stackexchange.com/q/2407
pub fn dayOfYear(year: u14, month: u4, day: u5) u9 {
    // TODO : do Neri-Schneider suggest a more efficient algorithm here ?
    const _month: i16 = @as(i16, month);
    const _day: i16 = @as(i16, day);
    const base_offset: i16 = @divFloor(_month * 275, 9);
    const feb_offset: i16 = if (month <= 2) 0 else 1;
    const leap_offset: i16 = if (isLeapYear(year)) 1 else 2;
    return @intCast(base_offset - (feb_offset * leap_offset) + _day - 30);
}

// helper
fn firstday(y: i16) i16 {
    return @mod((y + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400)), 7);
}

/// Number of ISO weeks per year
pub fn weeksPerYear(y: u14) u6 {
    return if (firstday(@as(i16, y)) == 4 or firstday(@as(i16, y - 1)) == 3) 53 else 52;
}

/// Number of ISO weeks per year, same as weeksPerYear but taking a datetime instance
pub fn weeksPerYear_(dt: Datetime) u7 {
    const this_y = Datetime.fromFields(.{ .year = dt.year }) catch unreachable;
    if (this_y.weekday() == Datetime.Weekday.Thursday) return 53;
    if (isLeapYear(dt.year) and this_y.weekday() == Datetime.Weekday.Wednesday) return 53;
    return 52;
}

/// Mapping of Unix time [s] to number of leap seconds n_leap; n_leap = array-index + 11;
/// UTC = TAI - n_leap
pub const leaps = [_]u48{
    // default to 10 leap seconds before 1972-07-01
    78796800, // 1972-07-01: now 11 leap seconds
    94694400, // 1973-01-01: ... 12
    126230400, // ... https://en.wikipedia.org/wiki/Leap_second
    157766400,
    189302400,
    220924800,
    252460800,
    283996800,
    315532800,
    362793600,
    394329600,
    425865600,
    489024000,
    567993600,
    631152000,
    662688000,
    709948800,
    741484800,
    773020800,
    820454400,
    867715200,
    915148800,
    1136073600,
    1230768000,
    1341100800,
    1435708800, // ...
    1483228800, // 2017-01-01
};

/// For a given Unix time in seconds, give me the number of leap seconds that
/// were added in UTC.
pub fn leapCorrection(unixtime: i64) u8 {
    if (unixtime < leaps[0]) return 10;
    if (unixtime >= leaps[leaps.len - 1]) return leaps.len + 10;
    const index = index: {
        var left: usize = 0;
        var right: usize = leaps.len;
        var mid: usize = 0;
        while (left < right) {
            mid = left + (right - left) / 2;
            switch (std.math.order(unixtime, leaps[mid])) {
                .eq => break :index mid,
                .gt => left = mid + 1,
                .lt => right = mid,
            }
        }
        break :index mid - @intFromBool(leaps[mid] > unixtime);
    };
    return @intCast(index + 11);
}

/// Calculate days since the Unix epoch (1970-01-01) from a year-month-day tuple,
/// representing a Gregorian calendar date.
/// (!) assumes the caller has checked the validity of the input.
/// Based on Howard Hinnant 'date' algorithms, https://howardhinnant.github.io/date_algorithms.html
pub fn unixdaysFromDate(ymd: [3]u16) i32 {
    // year: account for era starting in Mar (computational calendar)
    const y = if (ymd[1] <= 2) ymd[0] - 1 else ymd[0];

    // era - multiples of 400 years
    // H. Hinnant's code uses an Int here; however, since we do not allow
    // year <= 0, we can use the same unsigned type used in the ymd array.
    const era = y / 400;

    // year-of-era
    const yoe = (y - era * 400); // [0, 399]

    // day-of-year
    const doy = (153 * (if (ymd[1] > 2) ymd[1] - 3 else ymd[1] + 9) + 2) / 5 + ymd[2] - 1; // [0, 365]

    // day-of-era
    const doe: u32 = @as(u32, yoe) * 365 + yoe / 4 - yoe / 100 + doy; // [0, 146096]

    // cast down to 32 bits, which are sufficient
    const tmp: i32 = @intCast(@as(u32, era) * 146097 + doe);

    return tmp - 719468;
}

/// Calculate a Gregorian calendar date (year-month-day) from days since
/// the Unix epoch, 1970-01-01 00:00 Z.
/// The result is time zone naive, however resembles UTC since that is what
/// the Unix epoch refers to.
/// Based on Howard Hinnant 'date' algorithms, https://howardhinnant.github.io/date_algorithms.html
pub fn dateFromUnixdays(unix_days: i32) [3]u16 { // i23 should covert the range used here ?!
    // shift the epoch from 1970-01-01 to 0000-03-01
    // ...so long ago that all the times are positive => round to zero and round down coincide
    const z: u32 = @intCast(unix_days + 719468);

    // compute the era from the serial date by dividing by the number of days in an era (146097)
    // floored or Euclidean division must be used to correctly handle negative days
    const era = if (z >= 0) z / 146097 else z - 14096;

    // day-of-era
    // found by subtracting the era number times the number of days per era, from the serial date
    // this is the same as the modulo operation, but assuming floored or Euclidean division
    const doe = z - era * 146097; // [0, 146096]

    // year-of-era
    // start by appoximation (divide by 365), then account for leap years
    const yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; // [0, 399]

    // day-of-year
    // subtract from the day-of-era the days that have occurred in all prior years of this era
    // note: this is relative to the era which starts Mar 01
    const doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]

    // month
    // compute the day-of-year from the first day of month m'
    // where m' is in the range [0...11] representing [Mar...Feb]
    const mp = (5 * doy + 2) / 153; // [0, 11]

    // day
    const d: u16 = @intCast(doy - (153 * mp + 2) / 5 + 1); // [1, 31]

    // month; account for era starting with Mar
    const m: u16 = @intCast(if (mp < 10) mp + 3 else mp - 9);

    // year from era and year-of-era
    const y: u16 = @intCast(if (m <= 2) yoe + era * 400 + 1 else yoe + era * 400);

    return [_]u16{ y, m, d };
}

//
//
// --- from https://github.com/travisstaloch/date-zig/blob/main/src/lib.zig ---
// --- vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv ---
//
/// Determine if the given year is a leap year
///
/// # Panics
///
/// Year must be between [YEAR_MIN] and [YEAR_MAX] inclusive. Bounds are checked
/// using `std.debug.assert` only, so that the checks are not present in release
/// builds, similar to integer overflow checks.
///
/// # Examples
///
/// ```
/// try expectEqual(is_leap_year(2023), false);
/// try expectEqual(is_leap_year(2024), true);
/// try expectEqual(is_leap_year(2100), false);
/// try expectEqual(is_leap_year(2400), true);
/// ```
///
/// # Algorithm
///
/// Algorithm is Neri-Schneider from C++now 2023 conference:
/// > https://github.com/boostcon/cppnow_presentations_2023/blob/main/cppnow_slides/Speeding_Date_Implementing_Fast_Calendar_Algorithms.pdf
pub fn isLeapYear(y: u16) bool {
    // Using `%` instead of `&` causes compiler to emit branches instead. This
    // is faster in a tight loop due to good branch prediction, but probably
    // slower in a real program so we use `&`. Also `% 25` is functionally
    // equivalent to `% 100` here, but a little cheaper to compute. If branches
    // were to be emitted, using `% 100` would be most likely faster due to
    // better branch prediction.
    return if (@mod(y, 25) != 0)
        y & 3 == 0
    else
        y & 15 == 0;
    // NOTE : this is actually slower than the standard lib implementation
}

/// Determine the number of days in the given month in the given year
///
/// # Panics
///
/// Year must be between [YEAR_MIN] and [YEAR_MAX]. Month must be between `1`
/// and `12`. Bounds are checked using `std.debug.assert` only, so that the checks
/// are not present in release builds, similar to integer overflow checks.
///
/// # Example
///
/// ```
/// try expectEqual(days_in_month(2023, 1), 31);
/// try expectEqual(days_in_month(2023, 2), 28);
/// try expectEqual(days_in_month(2023, 4), 30);
/// try expectEqual(days_in_month(2024, 1), 31);
/// try expectEqual(days_in_month(2024, 2), 29);
/// try expectEqual(days_in_month(2024, 4), 30);
/// ```
///
/// # Algorithm
///
/// Algorithm is Neri-Schneider from C++now 2023 conference:
/// > https://github.com/boostcon/cppnow_presentations_2023/blob/main/cppnow_slides/Speeding_Date_Implementing_Fast_Calendar_Algorithms.pdf
pub fn daysInMonth_(y: i32, m: u8) u8 {
    return if (m != 2) 30 | (m ^ (m >> 3)) else if (isLeapYear(y)) 29 else 28;
}
//
/// Adjustment from Unix epoch to make calculations use positive integers
///
/// Unit is eras, which is defined to be 400 years, as that is the period of the
/// proleptic Gregorian calendar. Selected to place Unix epoch roughly in the
/// center of the value space, can be arbitrary within type limits.
const ERA_OFFSET: i32 = 3670;
/// Every era has 146097 days
const DAYS_IN_ERA: i32 = 146097;
/// Every era has 400 years
const YEARS_IN_ERA: i32 = 400;
/// Number of days from 0000-03-01 to Unix epoch 1970-01-01
const DAYS_TO_UNIX_EPOCH: i32 = 719468;
/// Offset to be added to given day values
const DAY_OFFSET: i32 = ERA_OFFSET * DAYS_IN_ERA + DAYS_TO_UNIX_EPOCH;
/// Offset to be added to given year values
const YEAR_OFFSET: i32 = ERA_OFFSET * YEARS_IN_ERA;
/// Seconds in a single 24 hour calendar day
const SECS_IN_DAY: i64 = 86400;
/// Offset to be added to given second values
const SECS_OFFSET: i64 = DAY_OFFSET * SECS_IN_DAY;

/// Convert Rata Die / days since 0001-01-01 to Gregorian date
///
/// Given a day counting from Unix epoch (January 1st, 1970) returns a
/// `(year, month, day)` triple.
///
/// ## Algorithm
///
/// > Neri C, Schneider L. "*Euclidean affine functions and their application to
/// > calendar algorithms*". Softw Pract Exper. 2022;1-34. DOI:
/// > [10.1002/spe.3172](https://onlinelibrary.wiley.com/doi/full/10.1002/spe.3172).
pub fn rdToDate(rd: i32) [3]u16 {
    const n0: u32 = @intCast(rd +% DAY_OFFSET);
    // century
    const n1 = 4 * n0 + 3;
    const c = n1 / 146097;
    const r = n1 % 146097;
    // year
    const n2 = r | 3;
    const p: u64 = 2939745 * @as(u64, n2);
    const z: u32 = @truncate(p / (1 << 32));
    const n3: u32 = @truncate((p % (1 << 32)) / 2939745 / 4);
    const j = @intFromBool(n3 >= 306);
    const y1: u32 = 100 * c + z + j;
    // month and day
    const n4 = 2141 * n3 + 197913;
    const m1 = n4 / (1 << 16);
    const d1 = n4 % (1 << 16) / 2141;
    // map
    const y = (@as(i32, @intCast(y1))) -% (YEAR_OFFSET);
    const m = if (j != 0) m1 - 12 else m1;
    const d = d1 + 1;
    return [3]u16{ @intCast(y), @intCast(m), @intCast(d) };
}

/// Convert Gregorian date to Rata Die / days since 0001-01-01
///
/// Given a `year, month, day` returns the days since Unix epoch
/// (January 1st, 1970). Dates before the epoch produce negative values.
///
/// ## Algorithm
///
/// > Neri C, Schneider L. "*Euclidean affine functions and their application to
/// > calendar algorithms*". Softw Pract Exper. 2022;1-34. DOI:
/// > [10.1002/spe.3172](https://onlinelibrary.wiley.com/doi/full/10.1002/spe.3172).
pub fn dateToRD(ymd: [3]u16) i32 {
    const y1: u32 = @intCast(ymd[0] +% YEAR_OFFSET);
    // map
    const jf: u32 = @intFromBool(ymd[1] < 3);
    const y2 = y1 -% jf;
    const m1 = @as(u32, ymd[1]) + 12 * jf;
    const d1 = @as(u32, ymd[2]) -% 1;
    // century
    const c = y2 / 100;
    // year
    const y3 = 1461 * y2 / 4 - c + c / 4;
    // month
    const m = (979 * m1 - 2919) / 32;
    // result
    const n = y3 +% m +% d1;
    return @as(i32, @intCast(n)) -% DAY_OFFSET;
}
