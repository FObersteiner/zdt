//! datetime
const std = @import("std");

const cal = @import("calendar.zig");
const Duration = @import("Duration.zig");
const tz = @import("timezone.zig");

// TODO : make this a "struct-file" ?

pub const min_year: u14 = 1; // r.d.; 0001-01-01
pub const max_year: u14 = 9999;
pub const unix_s_min: i40 = -62135596800;
pub const unix_s_max: i40 = 253402300799;

/// Combines error sets from the specific packages:
pub const ZdtError = RangeError || tz.TzError;

/// Errors that are caused by fields being out of defined ranges
pub const RangeError = error{
    YearOutOfRange,
    MonthOutOfRange,
    DayOutOfRange,
    HourOutOfRange,
    MinuteOutOfRange,
    SecondOutOfRange,
    NanosecondOutOfRange,
    UnixOutOfRange,
};

// helper constants with the number of bits limited to what is required
const s_per_minute: u6 = 60;
const s_per_hour: u12 = 3600;
const s_per_day: u17 = 86400;
const ms_per_s: u10 = 1_000;
const us_per_s: u20 = 1_000_000;
const ns_per_s: u30 = 1_000_000_000;

/// A helper struct to provide default values for a datetime instance.
pub const DatetimeFields = struct {
    year: u14 = 1, // [1, 9999]
    // We need to cover potential invalid input from a datetime string, e.g.
    // '99' for the hour field:
    month: u7 = 1, // [1, 12]
    day: u7 = 1, // [1, 32]
    hour: u7 = 0, // [0, 23]
    minute: u7 = 0, // [0, 59]
    second: u7 = 0, // [0, 60]

    nanosecond: u30 = 0, // [0, 999999999]
    tzinfo: ?tz.TZ = null,

    pub fn validate(self: DatetimeFields) ZdtError!void {
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

/// A representation of date and time. By default, it is naive, meaning no
/// time zone information (tzinfo) is specified (Null).
pub const Datetime = struct {
    year: u14 = 1, // [1, 9999]
    month: u4 = 1, // [1, 12]
    day: u5 = 1, // [1, 32]
    hour: u5 = 0, // [0, 23]
    minute: u6 = 0, // [0, 59]
    second: u6 = 0, // [0, 60]
    nanosecond: u30 = 0, // [0, 999999999]
    tzinfo: ?tz.TZ = null,

    // Seconds since the Unix epoch as internal, incremental time ("serial" time).
    // This must always refer to 1970-01-01T00:00:00Z, not counting leap seconds
    __unix: i40 = unix_s_min, // [unix_ns_min, unix_ns_max]

    pub fn fromFields(fields: DatetimeFields) ZdtError!Datetime {
        _ = try fields.validate();
        const d = cal.unixdaysFromDate([_]u16{ fields.year, fields.month, fields.day });
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
        if (fields.tzinfo.?.tzOffset != null) {
            dt.__unix -= fields.tzinfo.?.tzOffset.?.seconds_east;
            return dt;
        }

        // A "real" time zone is more complicated. We have already calculated a
        // 'localized' Unix time, as dt.__unix.
        // For that, We can obtain a UTC offset, subtract it and see if we get the same datetime.
        const local_tz = try fields.tzinfo.?.atUnixtime(dt.__unix);
        const unix_guess_1 = dt.__unix - local_tz.tzOffset.?.seconds_east;
        var dt_guess_1 = try Datetime.fromUnix(unix_guess_1, Duration.Resolution.second, fields.tzinfo);
        dt_guess_1.nanosecond = fields.nanosecond;

        // However, we could still have an ambiguous datetime or a datetime in a gap of
        // a DST transition. To exclude that, we need the surrounding timetypes of the current one.
        const sts = getSurroundingTimetypes(local_tz.tzOffset.?.__transition_index, &local_tz.tzFile.?);

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
        if (dt_eq_guess_1 and dt_eq_guess_2) return ZdtError.AmbiguousDatetime;
        if (!dt_eq_guess_1 and !dt_eq_guess_2) return ZdtError.NonexistentDatetime;
        if (dt_eq_guess_1) return dt_guess_1;
        return dt_guess_2;
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

    /// Construct a datetime from a simple list of numbers representing
    /// year, month, day etc.
    pub fn naiveFromList(arr: [7]usize) ZdtError!Datetime {
        return try Datetime.fromFields(.{
            .year = @intCast(arr[0]),
            .month = @intCast(arr[1]),
            .day = @intCast(arr[2]),
            .hour = @intCast(arr[3]),
            .minute = @intCast(arr[4]),
            .second = @intCast(arr[5]),
            .nanosecond = @intCast(arr[6]),
        });
    }

    /// Construct a datetime from Unix time with a specific precision (time unit)
    pub fn fromUnix(n: i72, resolution: Duration.Resolution, tzinfo: ?tz.TZ) ZdtError!Datetime {
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

    /// Return Unix time for given datetime struct
    pub fn toUnix(self: Datetime, resolution: Duration.Resolution) i72 {
        switch (resolution) {
            .second => return @as(i72, self.__unix),
            .millisecond => return @as(i72, self.__unix) * ms_per_s + @divFloor(self.nanosecond, us_per_s),
            .microsecond => return @as(i72, self.__unix) * us_per_s + @divFloor(self.nanosecond, ms_per_s),
            .nanosecond => return @as(i72, self.__unix) * ns_per_s + self.nanosecond,
        }
    }

    /// Make a naive datetime local to a given time zone.
    /// Checks for non-existent and ambiguous datetime.
    /// 'null' can be supplied to make an aware datetime naive.
    pub fn tzLocalize(self: Datetime, tzinfo: ?tz.TZ) ZdtError!Datetime {
        if (self.tzinfo != null and tzinfo != null) return ZdtError.TzAlreadyDefined;
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

    /// Convert datetime to another timezone. The datetime must be aware.
    pub fn tzConvert(self: Datetime, new_tz: tz.TZ) ZdtError!Datetime {
        if (self.tzinfo == null) return ZdtError.TzUndefined;
        return Datetime.fromUnix(
            @as(i72, self.__unix) * ns_per_s + self.nanosecond,
            Duration.Resolution.nanosecond,
            new_tz,
        );
    }

    /// A helper to update datetime fields so that they agree with the __unix internal
    /// representation. Expexts a "local" unix time, to be corrected by the
    /// UTC offset of the time zone (if such is supplied).
    fn __normalize(self: *Datetime) ZdtError!void {
        var fake_unix = self.__unix; // "local" unix time to get the fields right
        if (self.tzinfo != null) {
            self.tzinfo = try self.tzinfo.?.atUnixtime(self.__unix);
            if (self.tzinfo.?.tzOffset != null) {
                fake_unix += self.tzinfo.?.tzOffset.?.seconds_east;
            }
        }
        const s_after_midnight: i32 = @intCast(@mod(fake_unix, s_per_day));
        const days: i32 = @intCast(@divFloor(fake_unix, s_per_day));
        const ymd: [3]u16 = cal.dateFromUnixdays(days);
        self.year = @intCast(ymd[0]);
        self.month = @intCast(ymd[1]);
        self.day = @intCast(ymd[2]);
        self.hour = @intCast(@divFloor(s_after_midnight, s_per_hour));
        self.minute = @intCast(@divFloor(@mod(s_after_midnight, s_per_hour), s_per_minute));
        self.second = @intCast(@mod(s_after_midnight, s_per_minute));
    }

    /// Floor a datetime to a certain timespan. Creates a new datetime instance.
    pub fn floorTo(self: Datetime, timespan: Duration.Timespan) !Datetime {
        // any other timespan than second can lead to ambiguous or non-existent
        // datetime - therefore we need to make a new datetime
        var fields = DatetimeFields{ .tzinfo = self.tzinfo };
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
    pub fn now(tzinfo: ?tz.TZ) Datetime {
        const t = std.time.nanoTimestamp();
        const dummy = Datetime{};
        return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tzinfo) catch dummy;
    }

    /// Now in UTC helper. Homage to the Python method with the same name,
    /// which is now deprecated. This one actually returns UTC ;-)
    pub fn utcnow() Datetime {
        const t = std.time.nanoTimestamp();
        const dummy = Datetime{};
        return Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, tz.UTC) catch dummy;
    }

    /// Compare two instances with respect to their Unix time.
    /// Ignores the time zone - however, both datetimes must either be aware or naive.
    pub fn compareUT(this: Datetime, other: Datetime) ZdtError!std.math.Order {
        // can only compare if both aware or naive, not a mix.
        if ((this.tzinfo != null and other.tzinfo == null) or
            (this.tzinfo == null and other.tzinfo != null)) return ZdtError.CompareNaiveAware;
        if (@as(i72, this.__unix) * ns_per_s + this.nanosecond > @as(i72, other.__unix) * ns_per_s + other.nanosecond) return .gt;
        if (@as(i72, this.__unix) * ns_per_s + this.nanosecond < @as(i72, other.__unix) * ns_per_s + other.nanosecond) return .lt;
        return .eq;
    }

    /// Compare wall time, irrespective of the time zone.
    pub fn compareWall(this: Datetime, other: Datetime) !std.math.Order {
        const _this = if (this.tzinfo != null) try this.tzLocalize(null) else this;
        const _other = if (other.tzinfo != null) try other.tzLocalize(null) else other;
        return try Datetime.compareUT(_this, _other);
    }

    /// Formatted printing for UTC offset
    pub fn formatOffset(self: Datetime, writer: anytype) !void {
        if (self.tzinfo == null) return; // if the tzinfo is null, we cannot do anything.
        if (self.tzinfo.?.tzOffset == null) return error.InvalidArgument;

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
        if (seconds > 0) try writer.print(":{d:0>2}", .{seconds});
    }

    /// Add a duration to a datetime.
    pub fn add(self: Datetime, td: Duration) ZdtError!Datetime {
        const ns: i72 = ( //
            @as(i72, self.__unix) * ns_per_s + //
            @as(i72, self.nanosecond) + //
            td.__sec * ns_per_s + //
            td.__nsec //
        );
        return try Datetime.fromUnix(ns, Duration.Resolution.nanosecond, self.tzinfo);
    }

    /// Subtract a duration from a datetime.
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

    /// Day of the year starting with 1 == yyyy-01-01.
    pub fn dayOfYear(self: Datetime) u9 {
        return cal.dayOfYear(self.year, self.month, self.day);
    }

    /// Number of the weekday starting at 0 == Sunday.
    pub fn weekdayNumber(self: Datetime) u3 {
        const days = cal.unixdaysFromDate([3]u16{ self.year, self.month, self.day });
        return cal.weekdayFromUnixdays(days);
    }

    /// ISO-number of the weekday, starting at 1 == Monday
    pub fn weekdayIsoNumber(self: Datetime) u3 {
        const days = cal.unixdaysFromDate([3]u16{ self.year, self.month, self.day });
        return cal.ISOweekdayFromUnixdays(days);
    }

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
};

/// Surrounding timetypes at a given transition index. This index might be
/// negative to indicate out-of-range values.
fn getSurroundingTimetypes(idx: i32, _tz: *const std.tz.Tz) [3]?*std.tz.Timetype {
    var surrounding = [3]?*std.tz.Timetype{ null, null, null };
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
