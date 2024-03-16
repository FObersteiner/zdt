//! an instant in time

const std = @import("std");
const log = std.log.scoped(.zdt__Datetime);

const cal = @import("./calendar.zig");
const Duration = @import("./Duration.zig");
const Timezone = @import("./Timezone.zig");
const tzif = @import("./tzif.zig");
const RangeError = @import("./errors.zig").RangeError;
const TzError = @import("./errors.zig").TzError;
const ZdtError = @import("./errors.zig").ZdtError;

const Datetime = @This();

year: u14 = 1, // [1, 9999]
month: u4 = 1, // [1, 12]
day: u5 = 1, // [1, 32]
hour: u5 = 0, // [0, 23]
minute: u6 = 0, // [0, 59]
second: u6 = 0, // [0, 60]
nanosecond: u30 = 0, // [0, 999999999]
tzinfo: ?Timezone = null,
dst_fold: ?u1 = null, // DST fold position; 0 = early side, 1 = late side

// Seconds since the Unix epoch as incremental time ("serial" time).
// This must always refer to 1970-01-01T00:00:00Z, not counting leap seconds
__unix: i40 = unix_s_min, // [unix_s_min, unix_s_max]

pub const min_year: u14 = 1; // r.d.; 0001-01-01
pub const max_year: u14 = 9999;
pub const unix_s_min: i40 = -62135596800;
pub const unix_s_max: i40 = 253402300799;
pub const epoch = Datetime{ .year = 1970, .__unix = 0, .tzinfo = Timezone.UTC };

// constants with the number of bits limited to what is required
const s_per_minute: u6 = 60;
const s_per_hour: u12 = 3600;
const s_per_day: u17 = 86400;
const ms_per_s: u10 = 1_000;
const us_per_s: u20 = 1_000_000;
const ns_per_s: u30 = 1_000_000_000;

pub const Weekday = enum(u3) {
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

pub const Month = enum(u4) {
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
    year: u14, // [1, 9999]
    isoweek: u6, // [1, 53]
    isoweekday: u3, // [1, 7]

    pub fn format(
        self: ISOCalendar,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "{d:0>4}-W{d:0>2}-{d}T{d:0>2}:{d:0>2}:{d:0>2}",
            .{ self.year, self.isoweek, self.isoweekday },
        );
    }
};

/// the fields of a datetime instance
pub const Fields = struct {
    year: u14 = 1, // [1, 9999]
    // u7 because we need to cover potential invalid input from a datetime string,
    // e.g.'99' for the hour field
    month: u7 = 1, // [1, 12]
    day: u7 = 1, // [1, 32]
    hour: u7 = 0, // [0, 23]
    minute: u7 = 0, // [0, 59]
    second: u7 = 0, // [0, 60]
    nanosecond: u30 = 0, // [0, 999999999]
    tzinfo: ?Timezone = null,
    dst_fold: ?u1 = null, // DST fold position; 0 = early side, 1 = late side

    pub fn validate(self: Fields) ZdtError!void {
        if (self.year > max_year or self.year < min_year) return ZdtError.YearOutOfRange;
        if (self.month > 12 or self.month < 1) return ZdtError.MonthOutOfRange;
        const max_days = cal.daysInMonth(@truncate(self.month), cal.isLeapYear(self.year));
        if (self.day > max_days or self.day < 1) return ZdtError.DayOutOfRange;
        if (self.hour > 23) return ZdtError.HourOutOfRange;
        if (self.minute > 59) return ZdtError.MinuteOutOfRange;
        if (self.second > 60) return ZdtError.SecondOutOfRange;
        if (self.nanosecond > 999999999) return ZdtError.NanosecondOutOfRange;

        // if a tz is provided, it must allow offset calculation, which requires
        // one of the types to be not-null:
        if (self.tzinfo != null) {
            if (self.tzinfo.?.tzFile == null and
                self.tzinfo.?.tzOffset == null and
                self.tzinfo.?.tzPosix == null)
            {
                return ZdtError.AllTZRulesUndefined;
            }
        }
    }
};

pub fn fromFields(fields: Fields) ZdtError!Datetime {
    _ = try fields.validate(); // TODO : should this only be called in debug builds ?
    const d = cal.dateToRD([_]u16{ fields.year, fields.month, fields.day });
    // Note : need to truncate seconds to 59 so that Unix time is correct
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
    const sts = __getSurroundingTimetypes(local_tz.__transition_index, &fields.tzinfo.?.tzFile.?);

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
    const unix_guess_2 = dt.__unix - @as(i48, @intCast(tt_guess.?.offset));
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
pub fn fromUnix(n: i72, resolution: Duration.Resolution, tzinfo: ?Timezone) ZdtError!Datetime {
    if (n > @as(i72, unix_s_max) * @intFromEnum(resolution) or
        n < @as(i72, unix_s_min) * @intFromEnum(resolution))
    {
        return ZdtError.UnixOutOfRange;
    }
    var _dt = Datetime{ .tzinfo = tzinfo };
    switch (resolution) {
        .second => {
            _dt.__unix = @intCast(n);
        },
        .millisecond => {
            _dt.__unix = @intCast(@divFloor(n, @as(i72, ms_per_s)));
            _dt.nanosecond = @intCast(@mod(n, @as(i72, ms_per_s)) * us_per_s);
        },
        .microsecond => {
            _dt.__unix = @intCast(@divFloor(n, @as(i72, us_per_s)));
            _dt.nanosecond = @intCast(@mod(n, @as(i72, us_per_s)) * ms_per_s);
        },
        .nanosecond => {
            _dt.__unix = @intCast(@divFloor(n, @as(i72, ns_per_s)));
            _dt.nanosecond = @intCast(@mod(n, @as(i72, ns_per_s)));
        },
    }

    try _dt.__normalize();
    return _dt;
}

/// A helper to update datetime fields so that they agree with the __unix internal
/// representation. Expects a "local" unix time, to be corrected by the
/// UTC offset of the time zone (if such is supplied).
fn __normalize(self: *Datetime) TzError!void {
    var fake_unix = self.__unix; // "local" Unix time to get the fields right
    if (self.tzinfo != null) {
        self.tzinfo.?.tzOffset = try self.tzinfo.?.atUnixtime(self.__unix);
        fake_unix += self.tzinfo.?.tzOffset.?.seconds_east;
    }
    const s_after_midnight: i32 = @intCast(@mod(fake_unix, s_per_day));
    const days: i32 = @intCast(@divFloor(fake_unix, s_per_day));
    const ymd: [3]u16 = cal.rdToDate(days);
    self.year = @intCast(ymd[0]);
    self.month = @intCast(ymd[1]);
    self.day = @intCast(ymd[2]);
    self.hour = @intCast(@divFloor(s_after_midnight, s_per_hour));
    self.minute = @intCast(@divFloor(@mod(s_after_midnight, s_per_hour), s_per_minute));
    self.second = @intCast(@mod(s_after_midnight, s_per_minute));
}

/// Return Unix time for given datetime struct
pub fn toUnix(self: Datetime, resolution: Duration.Resolution) i72 {
    switch (resolution) {
        .second => return @as(i72, self.__unix),
        .millisecond => return @as(i72, self.__unix) * ms_per_s + @divFloor(self.nanosecond, us_per_s),
        .microsecond => return @as(i72, self.__unix) * us_per_s + @divFloor(self.nanosecond, ms_per_s),
        .nanosecond => return @as(i72, self.__unix) * ns_per_s + self.nanosecond,
    }
}

/// Make a datetime local to a given time zone.
///
/// 'null' can be supplied to make an aware datetime naive.
pub fn tzLocalize(self: Datetime, tzinfo: ?Timezone) ZdtError!Datetime {
    return Datetime.fromFields(.{
        .year = self.year,
        .month = self.month,
        .day = self.day,
        .hour = self.hour,
        .minute = self.minute,
        .second = self.second,
        .nanosecond = self.nanosecond,
        .tzinfo = tzinfo,
    });
}

/// Convert datetime to another time zone. The datetime must be aware;
/// can only convert to another time zone if initial time zone is defined
pub fn tzConvert(self: Datetime, new_tz: Timezone) ZdtError!Datetime {
    if (self.tzinfo == null) return ZdtError.TzUndefined;
    return Datetime.fromUnix(
        @as(i72, self.__unix) * ns_per_s + self.nanosecond,
        Duration.Resolution.nanosecond,
        new_tz,
    );
}

/// Floor a datetime to a certain timespan. Creates a new datetime instance.
pub fn floorTo(self: Datetime, timespan: Duration.Timespan) !Datetime {
    // any other timespan than second can lead to ambiguous or non-existent
    // datetime - therefore we need to make a new datetime
    var fields = Fields{ .tzinfo = self.tzinfo };
    if (self.tzinfo != null and self.tzinfo.?.tzFile != null) {
        // tzOffset must be resetted so that fromFields method
        // re-calculates the offset for the new Unix time:
        fields.tzinfo.?.tzOffset = null;
    }
    switch (timespan) {
        .second => {
            fields.year = self.year;
            fields.month = self.month;
            fields.day = self.day;
            fields.hour = self.hour;
            fields.minute = self.minute;
            fields.second = self.second;
        },
        .minute => {
            fields.year = self.year;
            fields.month = self.month;
            fields.day = self.day;
            fields.hour = self.hour;
            fields.minute = self.minute;
        },
        .hour => {
            fields.year = self.year;
            fields.month = self.month;
            fields.day = self.day;
            fields.hour = self.hour;
        },
        .day => {
            fields.year = self.year;
            fields.month = self.month;
            fields.day = self.day;
        },
        else => return ZdtError.NotImplemented,
    }
    return try Datetime.fromFields(fields);
}

/// The current time with nanosecond resolution.
/// If 'null' is supplied as tzinfo, naive datetime resembling UTC is returned.
pub fn now(tzinfo: ?Timezone) Datetime {
    const t = std.time.nanoTimestamp();
    return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tzinfo) catch Datetime{};
}

/// Try to obtain datetime in the local time zone.
/// Requires allocator for the time zone object; must be de-initialized by the caller.
pub fn nowLocal(allocator: std.mem.Allocator) !Datetime {
    const tz = try Timezone.tzLocal(allocator);
    const t = std.time.nanoTimestamp();
    return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tz);
}

/// Compare two instances with respect to their Unix time.
/// Ignores the time zone - however, both datetimes must either be aware or naive.
pub fn compareUT(this: Datetime, other: Datetime) ZdtError!std.math.Order {
    // can only compare if both aware or naive, not a mix.
    if ((this.tzinfo != null and other.tzinfo == null) or
        (this.tzinfo == null and other.tzinfo != null)) return ZdtError.CompareNaiveAware;
    return std.math.order(
        @as(i72, this.__unix) * ns_per_s + this.nanosecond,
        @as(i72, other.__unix) * ns_per_s + other.nanosecond,
    );
}

/// Compare wall time, irrespective of the time zone.
pub fn compareWall(this: Datetime, other: Datetime) !std.math.Order {
    const _this = if (this.tzinfo != null) try this.tzLocalize(null) else this;
    const _other = if (other.tzinfo != null) try other.tzLocalize(null) else other;
    return try Datetime.compareUT(_this, _other);
}

/// Add a duration to a datetime. Makes a new datetime.
pub fn add(self: Datetime, td: Duration) ZdtError!Datetime {
    const ns: i72 = ( //
        @as(i72, self.__unix) * ns_per_s + //
        @as(i72, self.nanosecond) + //
        td.__sec * ns_per_s + //
        td.__nsec //
    );
    return try Datetime.fromUnix(ns, Duration.Resolution.nanosecond, self.tzinfo);
}

/// Subtract a duration from a datetime. Makes a new datetime.
pub fn sub(self: Datetime, td: Duration) ZdtError!Datetime {
    return self.add(.{ .__sec = td.__sec * -1, .__nsec = td.__nsec });
}

/// Calculate the duration between two datetimes, independent of the time zone.
pub fn diff(this: Datetime, other: Datetime) Duration {
    var s: i64 = this.__unix - other.__unix;
    var ns: i32 = @as(i32, this.nanosecond) - other.nanosecond;
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Calculate wall time difference between two timezone-aware datetimes.
pub fn diffWall(this: Datetime, other: Datetime) !Duration {
    if (this.tzinfo == null or other.tzinfo == null) return error.TzUndefined;
    if (this.tzinfo.?.tzOffset == null or other.tzinfo.?.tzOffset == null) return error.TzUndefined;

    var s: i64 = ((this.__unix - other.__unix) +
        (this.tzinfo.?.tzOffset.?.seconds_east - other.tzinfo.?.tzOffset.?.seconds_east));

    var ns: i32 = @as(i32, this.nanosecond) - other.nanosecond;
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Day of the year starting with 1 == yyyy-01-01 (strftime/strptime: %j).
pub fn dayOfYear(self: Datetime) u9 {
    return cal.dayOfYear(self.year, self.month, self.day);
}

/// Day of the week as an enum value; Sun as first day of the week
pub fn weekday(self: Datetime) Weekday {
    return std.meta.intToEnum(Weekday, self.weekdayNumber()) catch unreachable;
}

/// Number of the weekday starting at 0 == Sunday (strftime/strptime: %w).
pub fn weekdayNumber(self: Datetime) u3 {
    const days = cal.dateToRD([3]u16{ self.year, self.month, self.day });
    return cal.weekdayFromUnixdays(days);
}

/// ISO-number of the weekday, starting at 1 == Monday (strftime/strptime: %u).
pub fn weekdayIsoNumber(self: Datetime) u3 {
    const days = cal.dateToRD([3]u16{ self.year, self.month, self.day });
    return cal.ISOweekdayFromUnixdays(days);
}

pub fn monthEnum(self: Datetime) Month {
    return std.meta.intToEnum(Month, self.month) catch unreachable;
}

/// Roll datetime forward to the specified next weekday. Makes a new datetime.
pub fn nextWeekday(self: Datetime, d: Weekday) Datetime {
    var daysdiff: i4 = 0;
    if (self.weekday() == d) {
        daysdiff = 7;
    } else {
        daysdiff = cal.weekdayDifference(@intFromEnum(d), self.weekdayNumber());
        if (daysdiff < 0) daysdiff += 7; // ensure a positive shift since we want 'next'
    }
    const offset = Duration.fromTimespanMultiple(daysdiff, Duration.Timespan.day);
    return self.add(offset) catch self; // return unmodified copy on error
}

/// Roll datetime backward to the specified previous weekday.
pub fn previousWeekday(self: Datetime, d: Weekday) Datetime {
    var daysdiff: i4 = 0;
    if (self.weekday() == d) {
        daysdiff = -7;
    } else {
        daysdiff = cal.weekdayDifference(@intFromEnum(d), self.weekdayNumber());
        if (daysdiff > 0) daysdiff -= 7;
    }
    const offset = Duration.fromTimespanMultiple(daysdiff, Duration.Timespan.day);
    return self.add(offset) catch self; // return unmodified copy on error
}

/// nth weekday of given month and year, returned as a Datetime.
/// nth must be in range [1..5]; although 5 might return an error for certain year/month combinations.
pub fn nthWeekday(year: u14, month: u4, wd: Weekday, nth: u5) ZdtError!Datetime {
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
pub fn weekOfYearSun(dt: Datetime) u6 {
    const doy = dt.dayOfYear();
    const dow = dt.weekdayNumber();
    return @truncate(@divFloor(doy + 7 - dow, 7));
}

/// Week number of the year (Monday as the first day of the week) as returned from
/// strftime's %W
pub fn weekOfYearMon(dt: Datetime) u6 {
    const doy = dt.dayOfYear();
    const dow = dt.weekdayNumber();
    return @truncate(@divFloor((doy + 7 - if (dow > 0) dow - 1 else 6), 7));
}

/// Calculate the ISO week of the year and generate ISOCalendar.
/// Algorithm from <https://en.wikipedia.org/wiki/ISO_week_date>.
pub fn isocalendar(dt: Datetime) ISOCalendar {
    const doy: u9 = dt.dayOfYear();
    const dow: u9 = @as(u9, dt.weekdayIsoNumber());
    const w: u9 = @divFloor(10 + doy - dow, 7);
    const weeks: u6 = cal.weeksPerYear(dt.year);
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

/// Formatted printing for UTC offset
pub fn formatOffset(self: Datetime, writer: anytype) !void {
    // if the tzinfo or tzOffset is null, we cannot do anything:
    if (self.tzinfo == null) return;
    if (self.tzinfo.?.tzOffset == null) return;

    // If the tzinfo is defined for a specific datetime, it should contain
    // a fixed offset (calculated from tzfile etc.). It should not be necessary to
    // make the calculation here:
    const off = self.tzinfo.?.tzOffset.?.seconds_east;

    const absoff: u19 = if (off < 0) @intCast(off * -1) else @intCast(off);
    const sign = if (off < 0) "-" else "+";
    const hours = absoff / 3600;
    const minutes = (absoff % 3600) / 60;
    const seconds = (absoff % 3600) % 60;

    try writer.print("{s}{d:0>2}:{d:0>2}", .{ sign, hours, minutes });
    if (seconds > 0) {
        try writer.print(":{d:0>2}", .{seconds});
    }
}

/// Formatted printing for Datetime. Defaults to ISO8601 / RFC3339nano.
pub fn format(
    self: Datetime,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print(
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}",
        .{ self.year, self.month, self.day, self.hour, self.minute, self.second },
    );
    if (self.nanosecond != 0) try writer.print(".{d:0>9}", .{self.nanosecond});
    if (self.tzinfo != null) try self.formatOffset(writer);
}

/// Surrounding timetypes at a given transition index. This index might be
/// negative to indicate out-of-range values.
fn __getSurroundingTimetypes(idx: i32, _tz: *const tzif.Tz) [3]?*tzif.Timetype {
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
