//! calendrical calculations

const std = @import("std");
const log = std.log.scoped(.zdt__calendar);
const assert = std.debug.assert;
const testing = std.testing;

pub const YEAR_MIN = -32768;
pub const YEAR_MAX = 32767;

/// Date type to be used with the rd-2-date and date-2-rd functions.
pub const Date = struct {
    year: i32 = 0,
    month: u32 = 1,
    day: u32 = 1,
};

pub fn isLeapYear(year: i16) bool {
    if (@mod(year, 4) != 0)
        return false;
    if (@mod(year, 100) != 0)
        return true;
    return (0 == @mod(year, 400));
}

/// Number of days in a certain month of any year.
pub fn lastDayOfMonth(year: i16, month: u8) u8 {
    return daysInMonth(month, isLeapYear(year));
}

/// Calculate the day of the week (Sun = 0, Sat = 6) for given days after Unix epoch
pub fn weekdayFromUnixdays(unix_days: i32) u8 {
    // offset by +4 since Unix epoch falls on a Thursday
    // since @mod always returns a positive value, we do not have to treat negative unix_days separately
    return @intCast(@mod((unix_days + 4), 7));
}

/// Calculate the ISO day of the week (Mon = 1, Sun = 7) for given days after Unix epoch
pub fn ISOweekdayFromUnixdays(unix_days: i32) u8 {
    return @intCast(@mod((unix_days + 3), 7) + 1);
}

/// Test if a month is a leap month, i.e. Feb in a leap year.
pub fn isLeapMonth(year: i16, month: u8) bool {
    return isLeapYear(year) and month == 2;
}

/// Difference between weekdays; x-y. x and y both <= 6 and >= 0, result in range [0..6].
pub fn weekdayDifference(x: u8, y: u8) i8 {
    assert((x >= 0) and (x <= 6));
    assert((y >= 0) and (y <= 6));
    const z: i8 = @as(i8, @intCast(x)) - @as(i8, @intCast(y));
    if (z <= 6) return z;
    return z + 7;
}

/// Calculate the day of the year. Result is [1, 366].
/// See also https://astronomy.stackexchange.com/q/2407
pub fn dayOfYear(year: i16, month: u8, day: u8) u16 {
    const _month: i16 = @as(i16, month);
    const _day: i16 = @as(i16, day);
    const base_offset: i16 = @divFloor(_month * 275, 9);
    const feb_offset: i16 = if (month <= 2) 0 else 1;
    const leap_offset: i16 = if (isLeapYear(year)) 1 else 2;
    return @intCast(base_offset - (feb_offset * leap_offset) + _day - 30);
}

fn firstday(year: i16) i16 {
    return @mod((year + @divFloor(year, 4) - @divFloor(year, 100) + @divFloor(year, 400)), 7);
}

/// Number of ISO weeks per year
pub fn weeksPerYear(year: i16) u8 {
    return if (firstday(@as(i16, @intCast(year))) == 4 or firstday(@as(i16, @intCast(year - 1))) == 3) 53 else 52;
}

/// Mapping of Unix time [s] to number of leap seconds n_leap; n_leap = array-index + 11;
/// UTC = TAI - n_leap
pub const leaps = [_]u64{
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

/// Find the index in 'leap' where the respective value
/// directly precedes or is equal to input 'unixtime'
fn preceedingLeapIndex(unixtime: i64) usize {
    return blk: {
        var left: usize = 0;
        var right: usize = leaps.len;
        var mid: usize = 0;
        while (left < right) {
            mid = left + (right - left) / 2;
            switch (std.math.order(unixtime, leaps[mid])) {
                .eq => break :blk mid,
                .gt => left = mid + 1,
                .lt => right = mid,
            }
        }
        break :blk mid;
    };
}

/// Analyze if a given Unix time falls on a leap second
pub fn mightBeLeap(unixtime: i64) bool {
    if (unixtime < leaps[0] - 1) return false;
    if (unixtime >= leaps[leaps.len - 1]) return false;
    const idx = preceedingLeapIndex(unixtime - 1);
    return leaps[idx + 1] == unixtime + 1;
}

/// For a given Unix time in seconds, give me the number of leap seconds that
/// were added in UTC.
pub fn leapCorrection(unixtime: i64) u8 {
    if (unixtime < leaps[0]) return 10;
    if (unixtime >= leaps[leaps.len - 1]) return leaps.len + 10;
    const index = blk: {
        var left: usize = 0;
        var right: usize = leaps.len;
        var mid: usize = 0;
        while (left < right) {
            mid = left + (right - left) / 2;
            switch (std.math.order(unixtime, leaps[mid])) {
                .eq => break :blk mid,
                .gt => left = mid + 1,
                .lt => right = mid,
            }
        }
        break :blk mid - @intFromBool(leaps[mid] > unixtime);
    };
    return @intCast(index + 11);
}

/// Days per month, depending on if it comes from a leap year.
/// See <10.1002/spe.3172.>.
pub fn daysInMonth(m: u8, is_leap: bool) u8 {
    return if (m != 2) 30 | (m ^ (m >> 3)) else if (is_leap) 29 else 28;
}

//--- Gregorian Date <--> Days since the Unix epoch -----------------------------------------------

/// Calculate days since the Unix epoch (1970-01-01) from a year-month-day tuple,
/// representing a Gregorian calendar date.
///
/// (!) assumes the caller has checked the validity of the input.
///
/// Based on Howard Hinnant 'date' algorithms,
/// <https://howardhinnant.github.io/date_algorithms.html>.
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
/// the Unix epoch (1970-01-01).
/// The result is time zone naive, however resembles UTC since that is what
/// the Unix epoch refers to.
///
/// Based on Howard Hinnant 'date' algorithms,
/// <https://howardhinnant.github.io/date_algorithms.html>.
pub fn dateFromUnixdays(unix_days: i32) [3]u16 {
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
    // start by approximation (divide by 365), then account for leap years
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

// ----------------------------------------------------------------------------
// The following algorithms were translated from the supplemental material of
// ```
// Neri C, Schneider L. "Euclidean affine functions and their application to calendar algorithms".
// Softw Pract Exper. 2022;1-34.
// DOI: 10.1002/spe.3172.
// ```
// The C++ version can be found here:
// <https://github.com/cassioneri/eaf/blob/main/algorithms/neri_schneider.hpp>

// Shift and correction constants:
pub const S: u32 = 82;
pub const K: u32 = 719468 + 146097 * S;
pub const L: u32 = 400 * S;

/// Convert days since 1970-01-01 ('rata die') to Gregorian date.
pub fn rdToDate(N_U: i32) Date {
    // Rata die shift
    const N: u32 = @as(u32, @bitCast(N_U)) +% K;

    // Century
    const N_1: u32 = 4 * N + 3;
    const C: u32 = N_1 / 146097;
    const N_C: u32 = (N_1 % 146097) / 4;

    // Year
    const N_2: u32 = 4 * N_C + 3;
    const P_2: u64 = @as(u64, 2939745) * N_2;
    const Z: u32 = @intCast(P_2 / 4294967296);
    const N_Y: u32 = @intCast((P_2 % 4294967296) / 2939745 / 4);
    const Y: u32 = 100 * C + Z;

    // Month and day
    const N_3: u32 = 2141 * N_Y + 197913;
    const M: u32 = N_3 / 65536;
    const D: u32 = (N_3 % 65536) / 2141;

    // Map. (Notice the year correction, including type change.)
    const J: u32 = @intFromBool(N_Y >= 306);
    const Y_G: i32 = @intCast(@as(i32, @bitCast(Y -% L)) + @as(i32, @intCast(J)));
    const M_G: u32 = if (J != 0) M - 12 else M;
    const D_G: u32 = D + 1;

    return .{ .year = Y_G, .month = M_G, .day = D_G };
}

/// Convert Gregorian date to days since 1970-01-01 ('rata die').
pub fn dateToRD(date: Date) i32 {
    // Map. (Notice the year correction, including type change.)
    const J: u32 = @intFromBool(date.month <= 2);
    const Y: u32 = @as(u32, @bitCast(date.year)) +% L - J;
    const M: u32 = if (J != 0) date.month + 12 else date.month;
    const D: u32 = date.day - 1;
    const C: u32 = Y / 100;

    // Rata die
    const y_star: u32 = 1461 * Y / 4 - C + C / 4;
    const m_star: u32 = (979 * M - 2919) / 32;
    const N: u32 = y_star + m_star + D;

    // Rata die shift
    const N_U: i32 = @as(i32, @bitCast(N)) - K;

    return N_U;
}

//--- EASTER --------------------------------------------------------------------------------------

/// Calculate the Gregorian calendar Easter date, according to
/// <https://en.wikipedia.org/wiki/Date_of_Easter#Anonymous%20Gregorian%20algorithm>
pub fn gregorianEaster(year: i16) Date {
    const a: i32 = @mod(year, 19);
    const b: i32 = @divFloor(year, 100);
    const c: i32 = @mod(year, 100);
    const d = @divFloor(b, 4);
    const e = @mod(b, 4);
    const f = @divFloor((b + 8), 25);
    const g = @divFloor((b - f + 1), 3);
    const h = @mod((19 * a + b - d - g + 15), 30);
    const i = @divFloor(c, 4);
    const k = @mod(c, 4);
    const l = @mod((32 + 2 * e + 2 * i - h - k), 7);
    const m = @divFloor((a + 11 * h + 22), 451);
    const n = @divFloor((h + l - 7 * m + 114), 31);
    const o = @mod((h + l - 7 * m + 114), 31) + 1;

    return .{ .year = year, .month = @intCast(n), .day = @intCast(o) };
}

/// Calculate the Julian calendar Easter date, according to
/// <https://en.wikipedia.org/wiki/Date_of_Easter#Meeus's_Julian_algorithm>
pub fn julianEaster(year: i16) Date {
    const a: i32 = @mod(year, 4);
    const b: i32 = @mod(year, 7);
    const c: i32 = @mod(year, 19);
    const d = @mod((19 * c + 15), 30);
    const e = @mod((2 * a + 4 * b - d + 34), 7);
    const n = @divFloor((d + e + 114), 31);
    const o = @mod((d + e + 114), 31) + 1;

    return .{ .year = year, .month = @intCast(n), .day = @intCast(o) };
}

//--- TESTS ---------------------------------------------------------------------------------------

test "leap index" {
    try testing.expectEqual(0, preceedingLeapIndex(0));
    try testing.expectEqual(0, preceedingLeapIndex(78796800));
    try testing.expectEqual(0, preceedingLeapIndex(78796801));
    try testing.expectEqual(1, preceedingLeapIndex(94694400));
}

test "might be leap second" {
    try testing.expect(!mightBeLeap(0));
    try testing.expect(!mightBeLeap(820454398));
    try testing.expect(mightBeLeap(820454399));
    try testing.expect(!mightBeLeap(820454400));
    try testing.expect(mightBeLeap(1483228799));
    try testing.expect(!mightBeLeap(1483228800));
}

test "days_in_month" {
    var d = daysInMonth(2, std.time.epoch.isLeapYear(2020));
    try testing.expectEqual(29, d);
    d = daysInMonth(2, std.time.epoch.isLeapYear(2023));
    try testing.expectEqual(28, d);
    d = daysInMonth(12, std.time.epoch.isLeapYear(2023));
    try testing.expectEqual(31, d);

    // index 0 is a place-holder --------vv
    const DAYS_IN_REGULAR_MONTH = [_]u8{ 30, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    for (DAYS_IN_REGULAR_MONTH[1..], 1..) |m, idx| {
        const x = daysInMonth(@truncate(idx), std.time.epoch.isLeapYear(2021));
        try testing.expectEqual(x, m);
    }
}

test "is_leap_month" {
    try testing.expect(!isLeapMonth(1900, 7));
    try testing.expect(!isLeapMonth(2000, 3));
    try testing.expect(isLeapMonth(2000, 2));
    try testing.expect(isLeapMonth(2020, 2));
    try testing.expect(!isLeapMonth(2022, 2));
}

test "weekday difference" {
    // How many days to add to y to get to x
    try testing.expectEqual(0, weekdayDifference(0, 0));
    try testing.expectEqual(1, weekdayDifference(6, 5));
    try testing.expectEqual(-1, weekdayDifference(5, 6));
    try testing.expectEqual(-6, weekdayDifference(0, 6));
    try testing.expectEqual(6, weekdayDifference(6, 0));
}

test "weekday iso-weekday" {
    var i: i32 = 19732; // 2024-01-10; Wed; wd=3, isowd=3
    while (i < 19732 + 360) : (i += 1) {
        const wd = weekdayFromUnixdays(i);
        var isowd = ISOweekdayFromUnixdays(i);
        if (isowd == 7) isowd -= 7;
        try testing.expectEqual(wd, isowd);
    }
}

test "round-trip rd-date" {
    var y: i16 = YEAR_MIN;
    while (y < YEAR_MAX) : (y += 1) {
        const rd = dateToRD(.{ .year = y, .month = 1, .day = 1 });
        const dt = rdToDate(rd);
        try testing.expectEqual(Date{ .year = y, .month = 1, .day = 1 }, dt);
    }
}

test "round-trip date-rd" {
    var now: i32 = -12687794;
    var dt: Date = undefined;
    const max: i32 = dateToRD(.{ .year = YEAR_MAX, .month = 12, .day = 31 });
    while (now <= max) : (now += 1) {
        dt = rdToDate(now);
        const rd = dateToRD(.{ .year = dt.year, .month = dt.month, .day = dt.day });
        try testing.expectEqual(now, rd);
    }
}

test "unix-days_from_ymd" {
    var days = unixdaysFromDate([_]u16{ 1970, 1, 1 });
    var want: i32 = 0;
    try testing.expectEqual(want, days);
    days = dateToRD(.{ .year = 1970, .month = 1, .day = 1 });
    try testing.expectEqual(want, days);

    days = unixdaysFromDate([_]u16{ 1969, 12, 27 });
    want = -5;
    try testing.expectEqual(want, days);
    days = dateToRD(.{ .year = 1969, .month = 12, .day = 27 });
    try testing.expectEqual(want, days);

    days = unixdaysFromDate([_]u16{ 1, 1, 1 });
    want = -719162;
    try testing.expectEqual(want, days);
    days = dateToRD(.{ .year = 1, .month = 1, .day = 1 });
    try testing.expectEqual(want, days);

    days = unixdaysFromDate([_]u16{ 2023, 10, 23 });
    want = 19653;
    try testing.expectEqual(want, days);
    days = dateToRD(.{ .year = 2023, .month = 10, .day = 23 });
    try testing.expectEqual(want, days);

    // the day may overflow
    days = unixdaysFromDate([_]u16{ 1969, 12, 32 });
    want = 0;
    try testing.expectEqual(want, days);

    days = unixdaysFromDate([_]u16{ 2020, 1, 31 + 29 });
    want = 18321;
    try testing.expectEqual(want, days);

    // month may overflow as well
    days = unixdaysFromDate([_]u16{ 1969, 13, 1 });
    want = 0;
    try testing.expectEqual(want, days);
}

test "ymd_from_unix-days" {
    var date = rdToDate(0);
    var want = Date{ .year = 1970, .month = 1, .day = 1 };
    try testing.expectEqual(want, date);

    date = rdToDate(-719162);
    want = Date{ .year = 1, .month = 1, .day = 1 };
    try testing.expectEqual(want, date);

    date = rdToDate(19653);
    want = Date{ .year = 2023, .month = 10, .day = 23 };
    try testing.expectEqual(want, date);
}

test "Easter, Gregorian" {
    var ymd = gregorianEaster(2009);
    try testing.expectEqual(Date{ .year = 2009, .month = 4, .day = 12 }, ymd);
    ymd = gregorianEaster(1970);
    try testing.expectEqual(Date{ .year = 1970, .month = 3, .day = 29 }, ymd);
    ymd = gregorianEaster(2018);
    try testing.expectEqual(Date{ .year = 2018, .month = 4, .day = 1 }, ymd);
    ymd = gregorianEaster(2025);
    try testing.expectEqual(Date{ .year = 2025, .month = 4, .day = 20 }, ymd);
    ymd = gregorianEaster(2160);
    try testing.expectEqual(Date{ .year = 2160, .month = 3, .day = 23 }, ymd);

    // ensure there is no int overflow:
    var i: i16 = YEAR_MIN;
    while (i < 32767) : (i += 1) {
        _ = gregorianEaster(i);
    }
}

test "Easter, Julian" {
    var ymd = julianEaster(2008);
    try testing.expectEqual(Date{ .year = 2008, .month = 4, .day = 14 }, ymd);
    ymd = julianEaster(2009);
    try testing.expectEqual(Date{ .year = 2009, .month = 4, .day = 6 }, ymd);
    ymd = julianEaster(2010);
    try testing.expectEqual(Date{ .year = 2010, .month = 3, .day = 22 }, ymd);
    ymd = julianEaster(2011);
    try testing.expectEqual(Date{ .year = 2011, .month = 4, .day = 11 }, ymd);
    ymd = julianEaster(2016);
    try testing.expectEqual(Date{ .year = 2016, .month = 4, .day = 18 }, ymd);
    ymd = julianEaster(2025);
    try testing.expectEqual(Date{ .year = 2025, .month = 4, .day = 7 }, ymd);
    ymd = julianEaster(2026);
    try testing.expectEqual(Date{ .year = 2026, .month = 3, .day = 30 }, ymd);

    // ensure there is no int overflow:
    var i: i16 = -32768;
    while (i < 32767) : (i += 1) {
        _ = julianEaster(i);
    }
}

// ---vv--- test generated with Python scripts ---vv---

test "leap correction" {
    var corr: u8 = leapCorrection(0);
    try testing.expectEqual(@as(u8, 10), corr);
    corr = leapCorrection(78796799);
    try testing.expectEqual(@as(u8, 10), corr);
    corr = leapCorrection(78796800);
    try testing.expectEqual(@as(u8, 11), corr);
    corr = leapCorrection(94694399);
    try testing.expectEqual(@as(u8, 11), corr);
    corr = leapCorrection(94694400);
    try testing.expectEqual(@as(u8, 12), corr);
    corr = leapCorrection(126230399);
    try testing.expectEqual(@as(u8, 12), corr);
    corr = leapCorrection(126230400);
    try testing.expectEqual(@as(u8, 13), corr);
    corr = leapCorrection(157766399);
    try testing.expectEqual(@as(u8, 13), corr);
    corr = leapCorrection(157766400);
    try testing.expectEqual(@as(u8, 14), corr);
    corr = leapCorrection(189302399);
    try testing.expectEqual(@as(u8, 14), corr);
    corr = leapCorrection(189302400);
    try testing.expectEqual(@as(u8, 15), corr);
    corr = leapCorrection(220924799);
    try testing.expectEqual(@as(u8, 15), corr);
    corr = leapCorrection(220924800);
    try testing.expectEqual(@as(u8, 16), corr);
    corr = leapCorrection(252460799);
    try testing.expectEqual(@as(u8, 16), corr);
    corr = leapCorrection(252460800);
    try testing.expectEqual(@as(u8, 17), corr);
    corr = leapCorrection(283996799);
    try testing.expectEqual(@as(u8, 17), corr);
    corr = leapCorrection(283996800);
    try testing.expectEqual(@as(u8, 18), corr);
    corr = leapCorrection(315532799);
    try testing.expectEqual(@as(u8, 18), corr);
    corr = leapCorrection(315532800);
    try testing.expectEqual(@as(u8, 19), corr);
    corr = leapCorrection(362793599);
    try testing.expectEqual(@as(u8, 19), corr);
    corr = leapCorrection(362793600);
    try testing.expectEqual(@as(u8, 20), corr);
    corr = leapCorrection(394329599);
    try testing.expectEqual(@as(u8, 20), corr);
    corr = leapCorrection(394329600);
    try testing.expectEqual(@as(u8, 21), corr);
    corr = leapCorrection(425865599);
    try testing.expectEqual(@as(u8, 21), corr);
    corr = leapCorrection(425865600);
    try testing.expectEqual(@as(u8, 22), corr);
    corr = leapCorrection(489023999);
    try testing.expectEqual(@as(u8, 22), corr);
    corr = leapCorrection(489024000);
    try testing.expectEqual(@as(u8, 23), corr);
    corr = leapCorrection(567993599);
    try testing.expectEqual(@as(u8, 23), corr);
    corr = leapCorrection(567993600);
    try testing.expectEqual(@as(u8, 24), corr);
    corr = leapCorrection(631151999);
    try testing.expectEqual(@as(u8, 24), corr);
    corr = leapCorrection(631152000);
    try testing.expectEqual(@as(u8, 25), corr);
    corr = leapCorrection(662687999);
    try testing.expectEqual(@as(u8, 25), corr);
    corr = leapCorrection(662688000);
    try testing.expectEqual(@as(u8, 26), corr);
    corr = leapCorrection(709948799);
    try testing.expectEqual(@as(u8, 26), corr);
    corr = leapCorrection(709948800);
    try testing.expectEqual(@as(u8, 27), corr);
    corr = leapCorrection(741484799);
    try testing.expectEqual(@as(u8, 27), corr);
    corr = leapCorrection(741484800);
    try testing.expectEqual(@as(u8, 28), corr);
    corr = leapCorrection(773020799);
    try testing.expectEqual(@as(u8, 28), corr);
    corr = leapCorrection(773020800);
    try testing.expectEqual(@as(u8, 29), corr);
    corr = leapCorrection(820454399);
    try testing.expectEqual(@as(u8, 29), corr);
    corr = leapCorrection(820454400);
    try testing.expectEqual(@as(u8, 30), corr);
    corr = leapCorrection(867715199);
    try testing.expectEqual(@as(u8, 30), corr);
    corr = leapCorrection(867715200);
    try testing.expectEqual(@as(u8, 31), corr);
    corr = leapCorrection(915148799);
    try testing.expectEqual(@as(u8, 31), corr);
    corr = leapCorrection(915148800);
    try testing.expectEqual(@as(u8, 32), corr);
    corr = leapCorrection(1136073599);
    try testing.expectEqual(@as(u8, 32), corr);
    corr = leapCorrection(1136073600);
    try testing.expectEqual(@as(u8, 33), corr);
    corr = leapCorrection(1230767999);
    try testing.expectEqual(@as(u8, 33), corr);
    corr = leapCorrection(1230768000);
    try testing.expectEqual(@as(u8, 34), corr);
    corr = leapCorrection(1341100799);
    try testing.expectEqual(@as(u8, 34), corr);
    corr = leapCorrection(1341100800);
    try testing.expectEqual(@as(u8, 35), corr);
    corr = leapCorrection(1435708799);
    try testing.expectEqual(@as(u8, 35), corr);
    corr = leapCorrection(1435708800);
    try testing.expectEqual(@as(u8, 36), corr);
    corr = leapCorrection(1483228799);
    try testing.expectEqual(@as(u8, 36), corr);
    corr = leapCorrection(1483228800);
    try testing.expectEqual(@as(u8, 37), corr);
}

test "against Pyhton ordinal" {
    var days_want: i32 = 1962788;
    var days_hin: i32 = unixdaysFromDate([_]u16{ 7343, 12, 7 });
    var days_neri: i32 = dateToRD(.{ .year = 7343, .month = 12, .day = 7 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    var date_want = [_]u16{ 7343, 12, 7 };
    var date_want_ = Date{ .year = 7343, .month = 12, .day = 7 };
    var date_hin = dateFromUnixdays(1962788);
    var date_neri = rdToDate(1962788);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -252206;
    days_hin = unixdaysFromDate([_]u16{ 1279, 6, 26 });
    days_neri = dateToRD(.{ .year = 1279, .month = 6, .day = 26 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1279, 6, 26 };
    date_want_ = Date{ .year = 1279, .month = 6, .day = 26 };
    date_hin = dateFromUnixdays(-252206);
    date_neri = rdToDate(-252206);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -614260;
    days_hin = unixdaysFromDate([_]u16{ 288, 3, 19 });
    days_neri = dateToRD(.{ .year = 288, .month = 3, .day = 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 288, 3, 19 };
    date_want_ = Date{ .year = 288, .month = 3, .day = 19 };
    date_hin = dateFromUnixdays(-614260);
    date_neri = rdToDate(-614260);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2391126;
    days_hin = unixdaysFromDate([_]u16{ 8516, 9, 6 });
    days_neri = dateToRD(.{ .year = 8516, .month = 9, .day = 6 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8516, 9, 6 };
    date_want_ = Date{ .year = 8516, .month = 9, .day = 6 };
    date_hin = dateFromUnixdays(2391126);
    date_neri = rdToDate(2391126);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 434394;
    days_hin = unixdaysFromDate([_]u16{ 3159, 5, 2 });
    days_neri = dateToRD(.{ .year = 3159, .month = 5, .day = 2 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3159, 5, 2 };
    date_want_ = Date{ .year = 3159, .month = 5, .day = 2 };
    date_hin = dateFromUnixdays(434394);
    date_neri = rdToDate(434394);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 307988;
    days_hin = unixdaysFromDate([_]u16{ 2813, 3, 30 });
    days_neri = dateToRD(.{ .year = 2813, .month = 3, .day = 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2813, 3, 30 };
    date_want_ = Date{ .year = 2813, .month = 3, .day = 30 };
    date_hin = dateFromUnixdays(307988);
    date_neri = rdToDate(307988);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 217051;
    days_hin = unixdaysFromDate([_]u16{ 2564, 4, 7 });
    days_neri = dateToRD(.{ .year = 2564, .month = 4, .day = 7 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2564, 4, 7 };
    date_want_ = Date{ .year = 2564, .month = 4, .day = 7 };
    date_hin = dateFromUnixdays(217051);
    date_neri = rdToDate(217051);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -133898;
    days_hin = unixdaysFromDate([_]u16{ 1603, 5, 27 });
    days_neri = dateToRD(.{ .year = 1603, .month = 5, .day = 27 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1603, 5, 27 };
    date_want_ = Date{ .year = 1603, .month = 5, .day = 27 };
    date_hin = dateFromUnixdays(-133898);
    date_neri = rdToDate(-133898);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2369822;
    days_hin = unixdaysFromDate([_]u16{ 8458, 5, 9 });
    days_neri = dateToRD(.{ .year = 8458, .month = 5, .day = 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8458, 5, 9 };
    date_want_ = Date{ .year = 8458, .month = 5, .day = 9 };
    date_hin = dateFromUnixdays(2369822);
    date_neri = rdToDate(2369822);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -289267;
    days_hin = unixdaysFromDate([_]u16{ 1178, 1, 6 });
    days_neri = dateToRD(.{ .year = 1178, .month = 1, .day = 6 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1178, 1, 6 };
    date_want_ = Date{ .year = 1178, .month = 1, .day = 6 };
    date_hin = dateFromUnixdays(-289267);
    date_neri = rdToDate(-289267);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2119121;
    days_hin = unixdaysFromDate([_]u16{ 7771, 12, 16 });
    days_neri = dateToRD(.{ .year = 7771, .month = 12, .day = 16 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 7771, 12, 16 };
    date_want_ = Date{ .year = 7771, .month = 12, .day = 16 };
    date_hin = dateFromUnixdays(2119121);
    date_neri = rdToDate(2119121);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2387423;
    days_hin = unixdaysFromDate([_]u16{ 8506, 7, 18 });
    days_neri = dateToRD(.{ .year = 8506, .month = 7, .day = 18 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8506, 7, 18 };
    date_want_ = Date{ .year = 8506, .month = 7, .day = 18 };
    date_hin = dateFromUnixdays(2387423);
    date_neri = rdToDate(2387423);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1568271;
    days_hin = unixdaysFromDate([_]u16{ 6263, 10, 13 });
    days_neri = dateToRD(.{ .year = 6263, .month = 10, .day = 13 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6263, 10, 13 };
    date_want_ = Date{ .year = 6263, .month = 10, .day = 13 };
    date_hin = dateFromUnixdays(1568271);
    date_neri = rdToDate(1568271);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -354515;
    days_hin = unixdaysFromDate([_]u16{ 999, 5, 16 });
    days_neri = dateToRD(.{ .year = 999, .month = 5, .day = 16 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 999, 5, 16 };
    date_want_ = Date{ .year = 999, .month = 5, .day = 16 };
    date_hin = dateFromUnixdays(-354515);
    date_neri = rdToDate(-354515);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1757543;
    days_hin = unixdaysFromDate([_]u16{ 6781, 12, 28 });
    days_neri = dateToRD(.{ .year = 6781, .month = 12, .day = 28 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6781, 12, 28 };
    date_want_ = Date{ .year = 6781, .month = 12, .day = 28 };
    date_hin = dateFromUnixdays(1757543);
    date_neri = rdToDate(1757543);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1050506;
    days_hin = unixdaysFromDate([_]u16{ 4846, 3, 10 });
    days_neri = dateToRD(.{ .year = 4846, .month = 3, .day = 10 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4846, 3, 10 };
    date_want_ = Date{ .year = 4846, .month = 3, .day = 10 };
    date_hin = dateFromUnixdays(1050506);
    date_neri = rdToDate(1050506);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -585856;
    days_hin = unixdaysFromDate([_]u16{ 365, 12, 25 });
    days_neri = dateToRD(.{ .year = 365, .month = 12, .day = 25 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 365, 12, 25 };
    date_want_ = Date{ .year = 365, .month = 12, .day = 25 };
    date_hin = dateFromUnixdays(-585856);
    date_neri = rdToDate(-585856);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -594184;
    days_hin = unixdaysFromDate([_]u16{ 343, 3, 8 });
    days_neri = dateToRD(.{ .year = 343, .month = 3, .day = 8 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 343, 3, 8 };
    date_want_ = Date{ .year = 343, .month = 3, .day = 8 };
    date_hin = dateFromUnixdays(-594184);
    date_neri = rdToDate(-594184);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -326176;
    days_hin = unixdaysFromDate([_]u16{ 1076, 12, 17 });
    days_neri = dateToRD(.{ .year = 1076, .month = 12, .day = 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1076, 12, 17 };
    date_want_ = Date{ .year = 1076, .month = 12, .day = 17 };
    date_hin = dateFromUnixdays(-326176);
    date_neri = rdToDate(-326176);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 197872;
    days_hin = unixdaysFromDate([_]u16{ 2511, 10, 4 });
    days_neri = dateToRD(.{ .year = 2511, .month = 10, .day = 4 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2511, 10, 4 };
    date_want_ = Date{ .year = 2511, .month = 10, .day = 4 };
    date_hin = dateFromUnixdays(197872);
    date_neri = rdToDate(197872);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 256688;
    days_hin = unixdaysFromDate([_]u16{ 2672, 10, 15 });
    days_neri = dateToRD(.{ .year = 2672, .month = 10, .day = 15 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2672, 10, 15 };
    date_want_ = Date{ .year = 2672, .month = 10, .day = 15 };
    date_hin = dateFromUnixdays(256688);
    date_neri = rdToDate(256688);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1400451;
    days_hin = unixdaysFromDate([_]u16{ 5804, 4, 22 });
    days_neri = dateToRD(.{ .year = 5804, .month = 4, .day = 22 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 5804, 4, 22 };
    date_want_ = Date{ .year = 5804, .month = 4, .day = 22 };
    date_hin = dateFromUnixdays(1400451);
    date_neri = rdToDate(1400451);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1805887;
    days_hin = unixdaysFromDate([_]u16{ 6914, 5, 9 });
    days_neri = dateToRD(.{ .year = 6914, .month = 5, .day = 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6914, 5, 9 };
    date_want_ = Date{ .year = 6914, .month = 5, .day = 9 };
    date_hin = dateFromUnixdays(1805887);
    date_neri = rdToDate(1805887);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -607863;
    days_hin = unixdaysFromDate([_]u16{ 305, 9, 24 });
    days_neri = dateToRD(.{ .year = 305, .month = 9, .day = 24 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 305, 9, 24 };
    date_want_ = Date{ .year = 305, .month = 9, .day = 24 };
    date_hin = dateFromUnixdays(-607863);
    date_neri = rdToDate(-607863);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1634870;
    days_hin = unixdaysFromDate([_]u16{ 6446, 2, 14 });
    days_neri = dateToRD(.{ .year = 6446, .month = 2, .day = 14 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6446, 2, 14 };
    date_want_ = Date{ .year = 6446, .month = 2, .day = 14 };
    date_hin = dateFromUnixdays(1634870);
    date_neri = rdToDate(1634870);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 114823;
    days_hin = unixdaysFromDate([_]u16{ 2284, 5, 17 });
    days_neri = dateToRD(.{ .year = 2284, .month = 5, .day = 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2284, 5, 17 };
    date_want_ = Date{ .year = 2284, .month = 5, .day = 17 };
    date_hin = dateFromUnixdays(114823);
    date_neri = rdToDate(114823);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2284041;
    days_hin = unixdaysFromDate([_]u16{ 8223, 6, 30 });
    days_neri = dateToRD(.{ .year = 8223, .month = 6, .day = 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8223, 6, 30 };
    date_want_ = Date{ .year = 8223, .month = 6, .day = 30 };
    date_hin = dateFromUnixdays(2284041);
    date_neri = rdToDate(2284041);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2006650;
    days_hin = unixdaysFromDate([_]u16{ 7464, 1, 9 });
    days_neri = dateToRD(.{ .year = 7464, .month = 1, .day = 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 7464, 1, 9 };
    date_want_ = Date{ .year = 7464, .month = 1, .day = 9 };
    date_hin = dateFromUnixdays(2006650);
    date_neri = rdToDate(2006650);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2222408;
    days_hin = unixdaysFromDate([_]u16{ 8054, 9, 30 });
    days_neri = dateToRD(.{ .year = 8054, .month = 9, .day = 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8054, 9, 30 };
    date_want_ = Date{ .year = 8054, .month = 9, .day = 30 };
    date_hin = dateFromUnixdays(2222408);
    date_neri = rdToDate(2222408);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1566488;
    days_hin = unixdaysFromDate([_]u16{ 6258, 11, 25 });
    days_neri = dateToRD(.{ .year = 6258, .month = 11, .day = 25 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6258, 11, 25 };
    date_want_ = Date{ .year = 6258, .month = 11, .day = 25 };
    date_hin = dateFromUnixdays(1566488);
    date_neri = rdToDate(1566488);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1040431;
    days_hin = unixdaysFromDate([_]u16{ 4818, 8, 9 });
    days_neri = dateToRD(.{ .year = 4818, .month = 8, .day = 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4818, 8, 9 };
    date_want_ = Date{ .year = 4818, .month = 8, .day = 9 };
    date_hin = dateFromUnixdays(1040431);
    date_neri = rdToDate(1040431);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 205432;
    days_hin = unixdaysFromDate([_]u16{ 2532, 6, 15 });
    days_neri = dateToRD(.{ .year = 2532, .month = 6, .day = 15 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2532, 6, 15 };
    date_want_ = Date{ .year = 2532, .month = 6, .day = 15 };
    date_hin = dateFromUnixdays(205432);
    date_neri = rdToDate(205432);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1164957;
    days_hin = unixdaysFromDate([_]u16{ 5159, 7, 19 });
    days_neri = dateToRD(.{ .year = 5159, .month = 7, .day = 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 5159, 7, 19 };
    date_want_ = Date{ .year = 5159, .month = 7, .day = 19 };
    date_hin = dateFromUnixdays(1164957);
    date_neri = rdToDate(1164957);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1752397;
    days_hin = unixdaysFromDate([_]u16{ 6767, 11, 26 });
    days_neri = dateToRD(.{ .year = 6767, .month = 11, .day = 26 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6767, 11, 26 };
    date_want_ = Date{ .year = 6767, .month = 11, .day = 26 };
    date_hin = dateFromUnixdays(1752397);
    date_neri = rdToDate(1752397);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 447654;
    days_hin = unixdaysFromDate([_]u16{ 3195, 8, 21 });
    days_neri = dateToRD(.{ .year = 3195, .month = 8, .day = 21 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3195, 8, 21 };
    date_want_ = Date{ .year = 3195, .month = 8, .day = 21 };
    date_hin = dateFromUnixdays(447654);
    date_neri = rdToDate(447654);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2675835;
    days_hin = unixdaysFromDate([_]u16{ 9296, 3, 9 });
    days_neri = dateToRD(.{ .year = 9296, .month = 3, .day = 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9296, 3, 9 };
    date_want_ = Date{ .year = 9296, .month = 3, .day = 9 };
    date_hin = dateFromUnixdays(2675835);
    date_neri = rdToDate(2675835);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2926947;
    days_hin = unixdaysFromDate([_]u16{ 9983, 9, 17 });
    days_neri = dateToRD(.{ .year = 9983, .month = 9, .day = 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9983, 9, 17 };
    date_want_ = Date{ .year = 9983, .month = 9, .day = 17 };
    date_hin = dateFromUnixdays(2926947);
    date_neri = rdToDate(2926947);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -691905;
    days_hin = unixdaysFromDate([_]u16{ 75, 8, 18 });
    days_neri = dateToRD(.{ .year = 75, .month = 8, .day = 18 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 75, 8, 18 };
    date_want_ = Date{ .year = 75, .month = 8, .day = 18 };
    date_hin = dateFromUnixdays(-691905);
    date_neri = rdToDate(-691905);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2463506;
    days_hin = unixdaysFromDate([_]u16{ 8714, 11, 8 });
    days_neri = dateToRD(.{ .year = 8714, .month = 11, .day = 8 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8714, 11, 8 };
    date_want_ = Date{ .year = 8714, .month = 11, .day = 8 };
    date_hin = dateFromUnixdays(2463506);
    date_neri = rdToDate(2463506);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2660688;
    days_hin = unixdaysFromDate([_]u16{ 9254, 9, 19 });
    days_neri = dateToRD(.{ .year = 9254, .month = 9, .day = 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9254, 9, 19 };
    date_want_ = Date{ .year = 9254, .month = 9, .day = 19 };
    date_hin = dateFromUnixdays(2660688);
    date_neri = rdToDate(2660688);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -49503;
    days_hin = unixdaysFromDate([_]u16{ 1834, 6, 20 });
    days_neri = dateToRD(.{ .year = 1834, .month = 6, .day = 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1834, 6, 20 };
    date_want_ = Date{ .year = 1834, .month = 6, .day = 20 };
    date_hin = dateFromUnixdays(-49503);
    date_neri = rdToDate(-49503);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2209046;
    days_hin = unixdaysFromDate([_]u16{ 8018, 3, 1 });
    days_neri = dateToRD(.{ .year = 8018, .month = 3, .day = 1 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8018, 3, 1 };
    date_want_ = Date{ .year = 8018, .month = 3, .day = 1 };
    date_hin = dateFromUnixdays(2209046);
    date_neri = rdToDate(2209046);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 1053411;
    days_hin = unixdaysFromDate([_]u16{ 4854, 2, 21 });
    days_neri = dateToRD(.{ .year = 4854, .month = 2, .day = 21 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4854, 2, 21 };
    date_want_ = Date{ .year = 4854, .month = 2, .day = 21 };
    date_hin = dateFromUnixdays(1053411);
    date_neri = rdToDate(1053411);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 707952;
    days_hin = unixdaysFromDate([_]u16{ 3908, 4, 23 });
    days_neri = dateToRD(.{ .year = 3908, .month = 4, .day = 23 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3908, 4, 23 };
    date_want_ = Date{ .year = 3908, .month = 4, .day = 23 };
    date_hin = dateFromUnixdays(707952);
    date_neri = rdToDate(707952);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 446314;
    days_hin = unixdaysFromDate([_]u16{ 3191, 12, 20 });
    days_neri = dateToRD(.{ .year = 3191, .month = 12, .day = 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3191, 12, 20 };
    date_want_ = Date{ .year = 3191, .month = 12, .day = 20 };
    date_hin = dateFromUnixdays(446314);
    date_neri = rdToDate(446314);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -67034;
    days_hin = unixdaysFromDate([_]u16{ 1786, 6, 20 });
    days_neri = dateToRD(.{ .year = 1786, .month = 6, .day = 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1786, 6, 20 };
    date_want_ = Date{ .year = 1786, .month = 6, .day = 20 };
    date_hin = dateFromUnixdays(-67034);
    date_neri = rdToDate(-67034);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 183929;
    days_hin = unixdaysFromDate([_]u16{ 2473, 7, 31 });
    days_neri = dateToRD(.{ .year = 2473, .month = 7, .day = 31 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2473, 7, 31 };
    date_want_ = Date{ .year = 2473, .month = 7, .day = 31 };
    date_hin = dateFromUnixdays(183929);
    date_neri = rdToDate(183929);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 2483164;
    days_hin = unixdaysFromDate([_]u16{ 8768, 9, 3 });
    days_neri = dateToRD(.{ .year = 8768, .month = 9, .day = 3 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8768, 9, 3 };
    date_want_ = Date{ .year = 8768, .month = 9, .day = 3 };
    date_hin = dateFromUnixdays(2483164);
    date_neri = rdToDate(2483164);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = 692617;
    days_hin = unixdaysFromDate([_]u16{ 3866, 4, 28 });
    days_neri = dateToRD(.{ .year = 3866, .month = 4, .day = 28 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3866, 4, 28 };
    date_want_ = Date{ .year = 3866, .month = 4, .day = 28 };
    date_hin = dateFromUnixdays(692617);
    date_neri = rdToDate(692617);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);

    days_want = -290462;
    days_hin = unixdaysFromDate([_]u16{ 1174, 9, 29 });
    days_neri = dateToRD(.{ .year = 1174, .month = 9, .day = 29 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1174, 9, 29 };
    date_want_ = Date{ .year = 1174, .month = 9, .day = 29 };
    date_hin = dateFromUnixdays(-290462);
    date_neri = rdToDate(-290462);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want_, date_neri);
}
