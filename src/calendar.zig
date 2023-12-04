//! calendaric stuff

/// zero and index 0 is just a place-holder (no month '0')
pub const DAYS_IN_REGULAR_MONTH = [_]u5{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

/// days per month, depending on if it comes from a leap year
pub fn days_in_month(m: u8, is_leap: bool) u5 {
    if (m == 2) return 28 + @as(u5, @intFromBool(is_leap)) else return DAYS_IN_REGULAR_MONTH[m];
}

/// Calculate days since the Unix epoch (1970-01-01) from a year-month-day tuple,
/// representing a Gregorian calendar date.
/// (!) assumes the caller has checked the validity of the input.
/// Based on Howard Hinnant 'date' algorithms, https://howardhinnant.github.io/date_algorithms.html
pub fn unixdaysFromDate(ymd: [3]u16) i32 {
    // year: account for era starting in Mar
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

    // cast down to 32 bit, which are sufficient
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
