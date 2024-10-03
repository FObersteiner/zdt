//! an instant in time

const std = @import("std");
const log = std.log.scoped(.zdt__Datetime);

const cal = @import("./calendar.zig");
const str = @import("./string.zig");
const tzif = @import("./tzif.zig");

const Duration = @import("./Duration.zig");
const Timezone = @import("./Timezone.zig");

const RangeError = @import("./errors.zig").RangeError;
const TzError = @import("./errors.zig").TzError;
const ZdtError = @import("./errors.zig").ZdtError;

const Datetime = @This();

year: u16 = 1, // [1, 9999]
month: u8 = 1, // [1, 12]
day: u8 = 1, // [1, 32]
hour: u8 = 0, // [0, 23]
minute: u8 = 0, // [0, 59]
second: u8 = 0, // [0, 60]
nanosecond: u32 = 0, // [0, 999999999]
tzinfo: ?Timezone = null,
dst_fold: ?u1 = null, // DST fold position; 0 = early side, 1 = late side

// Internal field.
// Seconds since the Unix epoch as incremental time ("serial" time).
// This must always refer to 1970-01-01T00:00:00Z, not counting leap seconds
__unix: i64 = unix_s_min, // [unix_s_min, unix_s_max]

pub const min_year: u16 = 1; // r.d.; 0001-01-01
pub const max_year: u16 = 9999;
pub const unix_s_min: i64 = -62135596800;
pub const unix_s_max: i64 = 253402300799;
pub const epoch = Datetime{ .year = 1970, .__unix = 0, .tzinfo = Timezone.UTC };
pub const century: u16 = 2000;

const s_per_minute: u8 = 60;
const s_per_hour: u16 = 3600;
const s_per_day: u32 = 86400;
const ms_per_s: u16 = 1_000;
const us_per_s: u32 = 1_000_000;
const ns_per_s: u32 = 1_000_000_000;

pub const Weekday = enum(u8) {
    Sunday = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,

    pub fn shortName(w: Weekday) []const u8 {
        return @tagName(w)[0..3];
    }

    pub fn longName(w: Weekday) []const u8 {
        return @tagName(w);
    }
};

pub const Month = enum(u8) {
    January = 1,
    February = 2,
    March = 3,
    April = 4,
    May = 5,
    June = 6,
    July = 7,
    August = 8,
    September = 9,
    October = 10,
    November = 11,
    December = 12,

    pub fn shortName(m: Month) []const u8 {
        return @tagName(m)[0..3];
    }

    pub fn longName(m: Month) []const u8 {
        return @tagName(m);
    }
};

pub const ISOCalendar = struct {
    year: u16, // [1, 9999]
    isoweek: u8, // [1, 53]
    isoweekday: u8, // [1, 7]

    pub fn format(
        calendar: ISOCalendar,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "{d:0>4}-W{d:0>2}-{d}T{d:0>2}:{d:0>2}:{d:0>2}",
            .{ calendar.year, calendar.isoweek, calendar.isoweekday },
        );
    }
};

/// the fields of a datetime instance
pub const Fields = struct {
    year: u16 = 1, // [1, 9999]
    month: u8 = 1, // [1, 12]
    day: u8 = 1, // [1, 32]
    hour: u8 = 0, // [0, 23]
    minute: u8 = 0, // [0, 59]
    second: u8 = 0, // [0, 60]
    nanosecond: u32 = 0, // [0, 999999999]
    tzinfo: ?Timezone = null,
    dst_fold: ?u1 = null, // DST fold position; 0 = early side, 1 = late side

    pub fn validate(fields: Fields) ZdtError!void {
        if (fields.year > max_year or fields.year < min_year) return ZdtError.YearOutOfRange;
        if (fields.month > 12 or fields.month < 1) return ZdtError.MonthOutOfRange;
        const max_days = cal.daysInMonth(@truncate(fields.month), cal.isLeapYear(fields.year));
        if (fields.day > max_days or fields.day < 1) return ZdtError.DayOutOfRange;
        if (fields.hour > 23) return ZdtError.HourOutOfRange;
        if (fields.minute > 59) return ZdtError.MinuteOutOfRange;
        if (fields.second > 60) return ZdtError.SecondOutOfRange;
        if (fields.nanosecond > 999999999) return ZdtError.NanosecondOutOfRange;

        // if a tz is provided, it must allow offset calculation, which requires
        // one of the types to be not-null:
        if (fields.tzinfo) |tzinfo| {
            if (tzinfo.tzFile == null and
                // and tzinfo.tzPosix == null
                tzinfo.tzOffset == null)
            {
                return ZdtError.AllTZRulesUndefined;
            }
        }
    }
};

pub fn fromFields(fields: Fields) ZdtError!Datetime {
    _ = try fields.validate(); // TODO : should this only be called in debug builds ?
    const d = cal.dateToRD([_]u16{ fields.year, fields.month, fields.day });
    // Note : need to truncate seconds to 59 so that Unix time is 'correct'
    const s = if (fields.second == 60) 59 else fields.second;
    var dt = Datetime{
        .year = fields.year,
        .month = @truncate(fields.month),
        .day = @truncate(fields.day),
        .hour = @truncate(fields.hour),
        .minute = @truncate(fields.minute),
        .second = @truncate(fields.second),
        .nanosecond = fields.nanosecond,
        .tzinfo = fields.tzinfo,
        .dst_fold = fields.dst_fold,
        .__unix = ( //
            @as(i40, d) * s_per_day +
            @as(u17, fields.hour) * s_per_hour +
            @as(u12, fields.minute) * s_per_minute + s //
        ),
    };

    // Shortcut #1: if tzinfo is null, make and return naive datetime
    if (fields.tzinfo == null) {
        return dt;
    }

    // Shortcut #2: if we have a fixed offset tz, we can calculate Unix time easily
    if (fields.tzinfo.?.tzOffset != null and fields.tzinfo.?.tzFile == null) {
        dt.__unix -= fields.tzinfo.?.tzOffset.?.seconds_east;
        return dt;
    }

    // A "real" time zone is more complicated. We have already calculated a
    // 'localized' Unix time, as dt.__unix.
    // For that, We can obtain a UTC offset, subtract it and see if we get the same datetime.
    const local_tz = try fields.tzinfo.?.atUnixtime(dt.__unix);
    const unix_guess_1 = dt.__unix - local_tz.seconds_east;
    var dt_guess_1 = try Datetime.fromUnix(unix_guess_1, Duration.Resolution.second, fields.tzinfo);
    dt_guess_1.nanosecond = fields.nanosecond;

    // However, we could still have an ambiguous datetime or a datetime in a gap of
    // a DST transition. To exclude that, we need the surrounding timetypes of the current one.
    const sts = getSurroundingTimetypes(local_tz.__transition_index, &fields.tzinfo.?.tzFile.?);

    // #1 - if there are no surrounding timetypes, we can only use the first guessed datetime
    // to compare to.
    if (sts[0] == null and sts[2] == null) {
        if (Datetime.__equalFields(dt, dt_guess_1)) {
            return dt_guess_1;
        }
        return ZdtError.NotImplemented; // something went totally wrong...
    }

    // #2 - now we have either a preceding or a following timetype or both.
    // Let's try to use the preceding timetype first; if it is null, use the following.
    // Note : this is a bit optimistic since it assumes both "bracketing" timetypes
    //        share the same UTC offset.
    const tt_guess = if (sts[0] != null) sts[0] else sts[2];
    const unix_guess_2 = dt.__unix - @as(i64, @intCast(tt_guess.?.offset));
    var dt_guess_2 = try Datetime.fromUnix(unix_guess_2, Duration.Resolution.second, fields.tzinfo);
    dt_guess_2.nanosecond = fields.nanosecond;

    // Now we have
    // - dt         : the original fields
    // - dt_guess_1 : fields based on the initial guess of the UTC offset
    // - dt_guess_2 : fields based on the previous (or next) UTC offset of given time zone
    // This allows 3 outcomes:
    // dt neither matches dt_guess_1 nor dt_guess_2 => non-existent datetime
    // dt matches dt_guess_1 and dt_guess_2 => ambiguous datetime
    // dt matches either dt_guess_1 or dt_guess_2 => normal datetime
    const dt_eq_guess_1 = Datetime.__equalFields(dt, dt_guess_1);
    const dt_eq_guess_2 = Datetime.__equalFields(dt, dt_guess_2);

    // If both guessed datetimes share the fields with the initial dt,
    // we have an ambiguous datetime.
    if (dt_eq_guess_1 and dt_eq_guess_2) {
        // if 'dst_fold' is not specified, this should return an error.
        const fold = fields.dst_fold orelse return ZdtError.AmbiguousDatetime;
        switch (fold) {
            0 => { // we want the DST active / 'early' side
                if (dt_guess_1.tzinfo.?.tzOffset.?.is_dst) return dt_guess_1 else return dt_guess_2;
            },
            1 => { // we want the DST inactive / 'late' side
                if (dt_guess_1.tzinfo.?.tzOffset.?.is_dst) return dt_guess_2 else return dt_guess_1;
            },
        }
    }

    // If both guesses did not succeede, we have a non-existent datetime.
    // this should give an error.
    if (!dt_eq_guess_1 and !dt_eq_guess_2) return ZdtError.NonexistentDatetime;

    // If we came here, either guess 1 or guess 2 is correct.
    if (dt_eq_guess_1) return dt_guess_1 else return dt_guess_2;
}

/// A helper to compare datetime fields, excluding nanosecond field.
/// Used for determination of correct UTC offset with a time zone.
fn __equalFields(this: Datetime, other: Datetime) bool {
    return ( //
        this.year == other.year and
        this.month == other.month and
        this.day == other.day and
        this.hour == other.hour and
        this.minute == other.minute and
        this.second == other.second //
    );
}

/// Construct a datetime from Unix time with a specific precision (time unit)
pub fn fromUnix(quantity: i128, resolution: Duration.Resolution, tzinfo: ?Timezone) ZdtError!Datetime {
    if (quantity > @as(i128, unix_s_max) * @intFromEnum(resolution) or
        quantity < @as(i128, unix_s_min) * @intFromEnum(resolution))
    {
        return ZdtError.UnixOutOfRange;
    }
    var _dt = Datetime{ .tzinfo = tzinfo };
    switch (resolution) {
        .second => {
            _dt.__unix = @intCast(quantity);
        },
        .millisecond => {
            _dt.__unix = @intCast(@divFloor(quantity, @as(i128, ms_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, ms_per_s)) * us_per_s);
        },
        .microsecond => {
            _dt.__unix = @intCast(@divFloor(quantity, @as(i128, us_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, us_per_s)) * ms_per_s);
        },
        .nanosecond => {
            _dt.__unix = @intCast(@divFloor(quantity, @as(i128, ns_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, ns_per_s)));
        },
    }

    try _dt.__normalize();
    return _dt;
}

/// A helper to update datetime fields so that they agree with the __unix internal
/// representation. Expects a "local" unix time, to be corrected by the
/// UTC offset of the time zone (if such is supplied).
fn __normalize(dt: *Datetime) TzError!void {
    var fake_unix = dt.__unix; // "local" Unix time to get the fields right
    if (dt.isAware()) {
        dt.tzinfo.?.tzOffset = try dt.tzinfo.?.atUnixtime(dt.__unix);
        fake_unix += dt.tzinfo.?.tzOffset.?.seconds_east;
    }
    const s_after_midnight: i32 = @intCast(@mod(fake_unix, s_per_day));
    const days: i32 = @intCast(@divFloor(fake_unix, s_per_day));
    const ymd: [3]u16 = cal.rdToDate(days);
    dt.year = @intCast(ymd[0]);
    dt.month = @intCast(ymd[1]);
    dt.day = @intCast(ymd[2]);
    dt.hour = @intCast(@divFloor(s_after_midnight, s_per_hour));
    dt.minute = @intCast(@divFloor(@mod(s_after_midnight, s_per_hour), s_per_minute));
    dt.second = @intCast(@mod(s_after_midnight, s_per_minute));
}

/// Return Unix time for given datetime struct
pub fn toUnix(dt: Datetime, resolution: Duration.Resolution) i128 {
    switch (resolution) {
        .second => return @as(i128, dt.__unix),
        .millisecond => return @as(i128, dt.__unix) * ms_per_s + @divFloor(dt.nanosecond, us_per_s),
        .microsecond => return @as(i128, dt.__unix) * us_per_s + @divFloor(dt.nanosecond, ms_per_s),
        .nanosecond => return @as(i128, dt.__unix) * ns_per_s + dt.nanosecond,
    }
}

/// true if a timezone has been set
pub fn isAware(dt: Datetime) bool {
    return dt.tzinfo != null;
}

/// alias for isAware
pub fn isZoned(dt: Datetime) bool {
    return dt.isAware();
}

/// true if no timezone is set
pub fn isNaive(dt: Datetime) bool {
    return !dt.isAware();
}

/// Make a datetime local to a given time zone.
///
/// 'null' can be supplied to make an aware datetime naive.
pub fn tzLocalize(dt: Datetime, tzinfo: ?Timezone) ZdtError!Datetime {
    return Datetime.fromFields(.{
        .year = dt.year,
        .month = dt.month,
        .day = dt.day,
        .hour = dt.hour,
        .minute = dt.minute,
        .second = dt.second,
        .nanosecond = dt.nanosecond,
        .tzinfo = tzinfo,
    });
}

/// Convert datetime to another time zone. The datetime must be aware;
/// can only convert to another time zone if initial time zone is defined
pub fn tzConvert(dt: Datetime, new_tz: Timezone) ZdtError!Datetime {
    if (dt.isNaive()) return ZdtError.TzUndefined;
    return Datetime.fromUnix(
        @as(i128, dt.__unix) * ns_per_s + dt.nanosecond,
        Duration.Resolution.nanosecond,
        new_tz,
    );
}

/// Floor a datetime to a certain timespan. Creates a new datetime instance.
pub fn floorTo(dt: Datetime, timespan: Duration.Timespan) !Datetime {
    // any other timespan than second can lead to ambiguous or non-existent
    // datetime - therefore we need to make a new datetime
    var fields = Fields{ .tzinfo = dt.tzinfo };
    if (dt.isAware() and dt.tzinfo.?.tzFile != null) {
        // tzOffset must be resetted so that fromFields method
        // re-calculates the offset for the new Unix time:
        fields.tzinfo.?.tzOffset = null;
    }
    switch (timespan) {
        .second => {
            fields.year = dt.year;
            fields.month = dt.month;
            fields.day = dt.day;
            fields.hour = dt.hour;
            fields.minute = dt.minute;
            fields.second = dt.second;
        },
        .minute => {
            fields.year = dt.year;
            fields.month = dt.month;
            fields.day = dt.day;
            fields.hour = dt.hour;
            fields.minute = dt.minute;
        },
        .hour => {
            fields.year = dt.year;
            fields.month = dt.month;
            fields.day = dt.day;
            fields.hour = dt.hour;
        },
        .day => {
            fields.year = dt.year;
            fields.month = dt.month;
            fields.day = dt.day;
        },
        else => return ZdtError.NotImplemented,
    }
    return try Datetime.fromFields(fields);
}

/// The current time with nanosecond resolution.
/// If 'null' is supplied as tzinfo, naive datetime resembling UTC is returned.
pub fn now(tzinfo: ?Timezone) ZdtError!Datetime {
    const t = std.time.nanoTimestamp();
    return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tzinfo);
}

/// Current UTC time is fail-safe since it contains a pre-defined time zone.
pub fn nowUTC() Datetime {
    const t = std.time.nanoTimestamp();
    return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, Timezone.UTC) catch unreachable;
}

/// Compare two instances with respect to their Unix time.
/// Ignores the time zone - however, both datetimes must either be aware or naive.
pub fn compareUT(this: Datetime, other: Datetime) ZdtError!std.math.Order {
    // can only compare if both aware or naive, not a mix.
    if ((this.isAware() and other.isNaive()) or
        (this.isNaive() and other.isAware())) return ZdtError.CompareNaiveAware;
    return std.math.order(
        @as(i128, this.__unix) * ns_per_s + this.nanosecond,
        @as(i128, other.__unix) * ns_per_s + other.nanosecond,
    );
}

/// Compare wall time, irrespective of the time zone.
pub fn compareWall(this: Datetime, other: Datetime) !std.math.Order {
    const _this = if (this.isAware()) try this.tzLocalize(null) else this;
    const _other = if (other.isAware()) try other.tzLocalize(null) else other;
    return try Datetime.compareUT(_this, _other);
}

/// Add a duration to a datetime. Makes a new datetime.
pub fn add(dt: Datetime, td: Duration) ZdtError!Datetime {
    const ns: i128 = ( //
        @as(i128, dt.__unix) * ns_per_s + //
        @as(i128, dt.nanosecond) + //
        td.__sec * ns_per_s + //
        td.__nsec //
    );
    return try Datetime.fromUnix(ns, Duration.Resolution.nanosecond, dt.tzinfo);
}

/// Subtract a duration from a datetime. Makes a new datetime.
pub fn sub(dt: Datetime, td: Duration) ZdtError!Datetime {
    return dt.add(.{ .__sec = td.__sec * -1, .__nsec = td.__nsec });
}

/// Calculate the duration between two datetimes, independent of the time zone.
pub fn diff(this: Datetime, other: Datetime) Duration {
    var s: i64 = this.__unix - other.__unix;
    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Calculate wall time difference between two timezone-aware datetimes.
pub fn diffWall(this: Datetime, other: Datetime) !Duration {
    if (this.isNaive() or other.isNaive()) return error.TzUndefined;
    if (this.tzinfo.?.tzOffset == null or other.tzinfo.?.tzOffset == null) return error.TzUndefined;

    var s: i64 = ((this.__unix - other.__unix) +
        (this.tzinfo.?.tzOffset.?.seconds_east - other.tzinfo.?.tzOffset.?.seconds_east));

    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Day of the year starting with 1 == yyyy-01-01 (strftime/strptime: %j).
pub fn dayOfYear(dt: Datetime) u16 {
    return cal.dayOfYear(dt.year, dt.month, dt.day);
}

/// Number of ISO weeks per year, same as weeksPerYear but taking a datetime instance
pub fn weeksInYear(dt: Datetime) u8 {
    return cal.weeksPerYear(dt.year);
}

/// Day of the week as an enum value; Sun as first day of the week
pub fn weekday(dt: Datetime) Weekday {
    return std.meta.intToEnum(Weekday, dt.weekdayNumber()) catch unreachable;
}

pub fn monthEnum(dt: Datetime) Month {
    return std.meta.intToEnum(Month, dt.month) catch unreachable;
}

/// Number of the weekday starting at 0 == Sunday (strftime/strptime: %w).
pub fn weekdayNumber(dt: Datetime) u8 {
    const days = cal.dateToRD([3]u16{ dt.year, dt.month, dt.day });
    return cal.weekdayFromUnixdays(days);
}

/// ISO-number of the weekday, starting at 1 == Monday (strftime/strptime: %u).
pub fn weekdayIsoNumber(dt: Datetime) u8 {
    const days = cal.dateToRD([3]u16{ dt.year, dt.month, dt.day });
    return cal.ISOweekdayFromUnixdays(days);
}

/// Roll datetime forward to the specified next weekday. Makes a new datetime.
pub fn nextWeekday(dt: Datetime, d: Weekday) Datetime {
    var daysdiff: i8 = 0;
    if (dt.weekday() == d) {
        daysdiff = 7;
    } else {
        daysdiff = cal.weekdayDifference(@intFromEnum(d), dt.weekdayNumber());
        if (daysdiff < 0) daysdiff += 7; // ensure a positive shift since we want 'next'
    }
    const offset = Duration.fromTimespanMultiple(daysdiff, Duration.Timespan.day);
    return dt.add(offset) catch dt; // return unmodified copy on error
}

/// Roll datetime backward to the specified previous weekday.
pub fn previousWeekday(dt: Datetime, d: Weekday) Datetime {
    var daysdiff: i8 = 0;
    if (dt.weekday() == d) {
        daysdiff = -7;
    } else {
        daysdiff = cal.weekdayDifference(@intFromEnum(d), dt.weekdayNumber());
        if (daysdiff > 0) daysdiff -= 7;
    }
    const offset = Duration.fromTimespanMultiple(daysdiff, Duration.Timespan.day);
    return dt.add(offset) catch dt; // return unmodified copy on error
}

/// nth weekday of given month and year, returned as a Datetime.
/// nth must be in range [1..5]; although 5 might return an error for certain year/month combinations.
pub fn nthWeekday(year: u16, month: u8, wd: Weekday, nth: u8) ZdtError!Datetime {
    if (nth > 5 or nth == 0) return RangeError.DayOutOfRange;
    var dt = try Datetime.fromFields(.{ .year = year, .month = month });
    if (dt.weekday() != wd) dt = dt.nextWeekday(wd);
    if (nth == 1) return dt;
    dt = try dt.add(Duration.fromTimespanMultiple(7 * (nth - 1), Duration.Timespan.day));
    if (dt.month != month) return RangeError.DayOutOfRange;
    return dt;
}

/// Week number of the year (Sunday as the first day of the week) as returned from
/// strftime's %U
pub fn weekOfYearSun(dt: Datetime) u8 {
    const doy = dt.dayOfYear() - 1; // [0..365]
    const dow = dt.weekdayNumber();
    return @truncate(@divFloor(doy + 7 - dow, 7));
}

/// Week number of the year (Monday as the first day of the week) as returned from
/// strftime's %W
pub fn weekOfYearMon(dt: Datetime) u8 {
    const doy = dt.dayOfYear(); // [1..366]
    const dow = dt.weekdayNumber();
    return @truncate(@divFloor((doy + 7 - if (dow > 0) dow - 1 else 6), 7));
}

/// Calculate the ISO week of the year and generate ISOCalendar.
/// Algorithm from <https://en.wikipedia.org/wiki/ISO_week_date>.
pub fn toISOCalendar(dt: Datetime) ISOCalendar {
    const doy: u16 = dt.dayOfYear();
    const dow: u16 = @as(u16, dt.weekdayIsoNumber());
    const w: u16 = @divFloor(10 + doy - dow, 7);
    const weeks: u8 = dt.weeksInYear();
    var isocal = ISOCalendar{ .year = dt.year, .isoweek = 0, .isoweekday = @truncate(dow) };
    if (w > weeks) {
        isocal.isoweek = 1;
        return isocal;
    }
    if (w < 1) {
        isocal.isoweek = cal.weeksPerYear(dt.year - 1);
        return isocal;
    }
    isocal.isoweek = @truncate(w);
    return isocal;
}

/// Parse a string to a datetime.
pub fn fromString(string: []const u8, directives: []const u8) !Datetime {
    return try str.tokenizeAndParse(string, directives);
}

/// Make a datetime from a string with an ISO8601-compatibel format.
pub fn fromISO8601(string: []const u8) !Datetime {
    // 9 digits of fractional seconds and hh:mm:ss UTC offset: 38 characters
    if (string.len > 38)
        return error.InvalidFormat;
    // last character must be Z (UTC) or a digit
    if (string[string.len - 1] != 'Z' and !std.ascii.isDigit(string[string.len - 1])) {
        return error.InvalidFormat;
    }
    var idx: usize = 0; // assume datetime starts at beginning of string
    return try Datetime.fromFields(try str.parseISO8601(string, &idx));
}

/// Format a datetime into a string
pub fn toString(dt: Datetime, directives: []const u8, writer: anytype) !void {
    return try str.tokenizeAndPrint(&dt, directives, writer);
}

pub fn tzName(dt: *Datetime) []const u8 {
    return @constCast(&dt.tzinfo.?).name();
}
pub fn tzAbbreviation(dt: *Datetime) []const u8 {
    return @constCast(&dt.tzinfo.?).abbreviation();
}

/// Formatted printing for UTC offset
pub fn formatOffset(
    dt: Datetime,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    // if the tzinfo or tzOffset is null, we cannot do anything:
    if (dt.isNaive()) return;
    if (dt.tzinfo.?.tzOffset == null) return;

    // If the tzinfo is defined for a specific datetime, it should contain
    // a fixed offset (calculated from tzfile etc.). It should not be necessary to
    // make the calculation here:
    const off = dt.tzinfo.?.tzOffset.?.seconds_east;
    const absoff: u32 = if (off < 0) @intCast(off * -1) else @intCast(off);
    const sign = if (off < 0) "-" else "+";
    const hours = absoff / 3600;
    const minutes = (absoff % 3600) / 60;
    const seconds = (absoff % 3600) % 60;

    // precision: 0 - hours, 1 - hours:minutes, 2 - hours:minutes:seconds
    const precision = if (options.precision) |p| p else 1;

    if (options.fill != 0) {
        try writer.print("{s}{d:0>2}", .{ sign, hours });
        if (precision > 0)
            try writer.print("{u}{d:0>2}", .{ options.fill, minutes });
        if (precision > 1)
            try writer.print("{u}{d:0>2}", .{ options.fill, seconds });
    } else {
        try writer.print("{s}{d:0>2}{d:0>2}", .{ sign, hours, minutes });
    }
}

/// Formatted printing for Datetime. Defaults to ISO8601 / RFC3339nano.
/// Nanoseconds are displayed if not zero. To get milli- or microsecond
/// precision, use formatting directive 's:.3' (ms) or 's:.6' (us).
pub fn format(
    dt: Datetime,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    try writer.print(
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}",
        .{ dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second },
    );

    if (options.precision) |p| switch (p) {
        3 => try writer.print(".{d:0>3}", .{dt.nanosecond / 1_000_000}),
        6 => try writer.print(".{d:0>6}", .{dt.nanosecond / 1_000}),
        9 => try writer.print(".{d:0>9}", .{dt.nanosecond}),
        else => if (dt.nanosecond != 0) try writer.print(".{d:0>9}", .{dt.nanosecond}),
    } else if (dt.nanosecond != 0) try writer.print(".{d:0>9}", .{dt.nanosecond});

    if (dt.tzinfo != null) try dt.formatOffset(.{ .fill = ':', .precision = 1 }, writer);
}

/// Surrounding timetypes at a given transition index. This index might be
/// negative to indicate out-of-range values.
pub fn getSurroundingTimetypes(idx: i32, _tz: *const tzif.Tz) [3]?*tzif.Timetype {
    var surrounding = [3]?*tzif.Timetype{ null, null, null };
    if (idx > 0) {
        surrounding[1] = _tz.transitions[@as(u64, @intCast(idx))].timetype;
    }
    if (idx >= 1) {
        surrounding[0] = _tz.transitions[@as(u64, @intCast(idx - 1))].timetype;
    }
    if (idx > 0 and idx < _tz.transitions.len - 1) {
        surrounding[2] = _tz.transitions[@as(u64, @intCast(idx + 1))].timetype;
    }
    return surrounding;
}
