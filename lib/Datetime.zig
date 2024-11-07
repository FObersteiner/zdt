//! an instant in time

const std = @import("std");
const log = std.log.scoped(.zdt__Datetime);
const assert = std.debug.assert;

const cal = @import("./calendar.zig");
const str = @import("./string.zig");
const tzif = @import("./tzif.zig");

const Duration = @import("./Duration.zig");
const Timezone = @import("./Timezone.zig");
const UTCoffset = @import("./UTCoffset.zig");

const RangeError = @import("./errors.zig").RangeError;
const TzError = @import("./errors.zig").TzError;
const ZdtError = @import("./errors.zig").ZdtError;

pub const min_year: u16 = 1; // r.d.; 0001-01-01
pub const max_year: u16 = 9999;
pub const unix_s_min: i64 = -62135596800;
pub const unix_s_max: i64 = 253402300799;
pub const epoch = Datetime{ .year = 1970, .unix_sec = 0, .utc_offset = UTCoffset.UTC };
pub const century: u16 = 2000;

const s_per_minute: u8 = 60;
const s_per_hour: u16 = 3600;
const s_per_day: u32 = 86400;
const ms_per_s: u16 = 1_000;
const us_per_s: u32 = 1_000_000;
const ns_per_s: u32 = 1_000_000_000;

const Datetime = @This();

/// Year. Do not modify directly.
year: u16 = 1, // [1, 9999]

/// Month. Do not modify directly.
month: u8 = 1, // [1, 12]

/// Day. Do not modify directly.
day: u8 = 1, // [1, 32]

/// Hour. Do not modify directly.
hour: u8 = 0, // [0, 23]

/// Minute. Do not modify directly.
minute: u8 = 0, // [0, 59]

/// Seconds. Do not modify directly.
second: u8 = 0, // [0, 60]

/// Nanoseconds. Do not modify directly.
nanosecond: u32 = 0, // [0, 999999999]

/// Corresponding seconds since the Unix epoch as incremental time ("serial" time).
/// Always refers to 1970-01-01T00:00:00Z, not counting leap seconds.
/// Do not modify directly.
unix_sec: i64 = unix_s_min, // [unix_s_min, unix_s_max]

/// Offset from UTC. Is calculated whenever a Timezone is defined for a datetime
/// or if the Timezone of a datetime is changed.
/// Do not modify directly.
utc_offset: ?UTCoffset = null,

/// Optional pointer to time zone rule set. Do not modify directly.
tz: ?*const Timezone = null,

/// intended DST fold position; 0 = early side, 1 = late side
dst_fold: ?u1 = null,

// ----------------------------------------------------------------------------

/// Enum-representation of a weekday, with Sunday being 0.
/// Mainly used to get locale-independent English names.
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

    pub fn nameToInt(name: []const u8) !u8 {
        inline for (std.meta.fields(Weekday)) |f| {
            if (std.mem.eql(u8, name, f.name)) return f.value;
        }
        return error.DayOutOfRange;
    }

    pub fn nameShortToInt(name: []const u8) !u8 {
        inline for (std.meta.fields(Weekday)) |f| {
            if (std.mem.eql(u8, name, f.name[0..3])) return f.value;
        }
        return error.DayOutOfRange;
    }
};

/// Enum-representation of a month, with January being 1.
/// Mainly used to get locale-independent English names.
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

    pub fn nameToInt(name: []const u8) !u8 {
        inline for (std.meta.fields(Month)) |f| {
            if (std.mem.eql(u8, name, f.name)) return f.value;
        }
        return error.MonthOutOfRange;
    }

    pub fn nameShortToInt(name: []const u8) !u8 {
        inline for (std.meta.fields(Month)) |f| {
            if (std.mem.eql(u8, name, f.name[0..3])) return f.value;
        }
        return error.MonthOutOfRange;
    }
};

pub const ISOCalendar = struct {
    isoyear: u16, // [1, 9999]
    isoweek: u8, // [1, 53]
    isoweekday: u8, // [1, 7]

    // Date of the first day of given ISO year
    fn yearStartDate(iso_year: u16) !Datetime {
        const fourth_jan = try Datetime.fromFields(.{ .year = iso_year, .month = 1, .day = 4 });
        return fourth_jan.sub(
            Duration.fromTimespanMultiple(@as(u16, fourth_jan.weekdayIsoNumber() - 1), Duration.Timespan.day),
        );
    }

    /// Gregorian calendar date for given ISOCalendar
    pub fn toDatetime(isocal: ISOCalendar) !Datetime {
        const year_start = try yearStartDate(isocal.isoyear);
        return year_start.add(
            Duration.fromTimespanMultiple(@as(u16, isocal.isoweekday - 1) + @as(u16, isocal.isoweek - 1) * 7, Duration.Timespan.day),
        );
    }

    pub fn fromString(string: []const u8) !ISOCalendar {
        if (string.len < 10) return error.InvalidFormat;
        if (string[4] != '-' or std.ascii.toLower(string[5]) != 'w' or string[8] != '-') return error.InvalidFormat;
        return .{
            .isoyear = try std.fmt.parseInt(u16, string[0..4], 10),
            .isoweek = try std.fmt.parseInt(u8, string[6..8], 10),
            .isoweekday = try std.fmt.parseInt(u8, string[9..10], 10),
        };
    }

    pub fn format(
        calendar: ISOCalendar,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "{d:0>4}-W{d:0>2}-{d}",
            .{ calendar.isoyear, calendar.isoweek, calendar.isoweekday },
        );
    }
};

const tzOpts = enum {
    tz,
    utc_offset,
};

/// helper to specify either a time zone or a UTC offset:
pub const tz_options = union(tzOpts) {
    tz: *const Timezone,
    utc_offset: UTCoffset,
};

/// The fields of a datetime instance.
pub const Fields = struct {
    year: u16 = 1, // [1, 9999]
    month: u8 = 1, // [1, 12]
    day: u8 = 1, // [1, 32]
    hour: u8 = 0, // [0, 23]
    minute: u8 = 0, // [0, 59]
    second: u8 = 0, // [0, 60]
    nanosecond: u32 = 0, // [0, 999999999]
    dst_fold: ?u1 = null,
    tz_options: ?tz_options = null,

    pub fn validate(fields: Fields) ZdtError!void {
        if (fields.year > max_year or fields.year < min_year) return ZdtError.YearOutOfRange;
        if (fields.month > 12 or fields.month < 1) return ZdtError.MonthOutOfRange;
        const max_days = cal.daysInMonth(@truncate(fields.month), cal.isLeapYear(fields.year));
        if (fields.day > max_days or fields.day < 1) return ZdtError.DayOutOfRange;
        if (fields.hour > 23) return ZdtError.HourOutOfRange;
        if (fields.minute > 59) return ZdtError.MinuteOutOfRange;
        if (fields.second > 60) return ZdtError.SecondOutOfRange;
        if (fields.nanosecond > 999999999) return ZdtError.NanosecondOutOfRange;
    }
};

/// Datetime fields without timezone and UTC offset. All fields optional and undefined by default.
/// Helper for Datetime.replace().
pub const OptFields = struct {
    year: ?u16 = null,
    month: ?u8 = null,
    day: ?u8 = null,
    hour: ?u8 = null,
    minute: ?u8 = null,
    second: ?u8 = null,
    nanosecond: ?u32 = null,
};

/// Make a valid datetime from fields.
pub fn fromFields(fields: Fields) ZdtError!Datetime {
    _ = try fields.validate();

    const d = cal.dateToRD([_]u16{ fields.year, fields.month, fields.day });
    // Note : need to truncate seconds to 59 so that Unix time is 'correct'
    const s = if (fields.second == 60) 59 else fields.second;
    var dt = Datetime{
        .year = fields.year,
        .month = fields.month,
        .day = fields.day,
        .hour = fields.hour,
        .minute = fields.minute,
        .second = fields.second,
        .nanosecond = fields.nanosecond,
        .unix_sec = ( //
            @as(i40, d) * s_per_day +
            @as(u17, fields.hour) * s_per_hour +
            @as(u12, fields.minute) * s_per_minute + s //
        ),
    };

    // verify that provided leap second datetime is valid
    if (dt.second == 60) _ = try dt.validateLeap();

    if (fields.tz_options) |opts| {
        switch (opts) {
            .utc_offset => {
                dt.utc_offset = fields.tz_options.?.utc_offset;
                // if the offset represents UTC, also set the tz pointer
                // for consistency:
                if (std.meta.eql(dt.utc_offset.?, UTCoffset.UTC)) dt.tz = &Timezone.UTC;
                // Shortcut #2: the tz pointer is not set here; we have a fixed offset,
                // can calculate Unix time easily and return.
                dt.unix_sec -= dt.utc_offset.?.seconds_east;
                return dt;
            },
            .tz => {
                dt.tz = fields.tz_options.?.tz;
                // if tz points to the UTC constant, we need to set the offset here
                // and again can return immediately:
                if (std.meta.eql(dt.tz.?.*, Timezone.UTC)) {
                    dt.utc_offset = UTCoffset.UTC;
                    return dt;
                }
            },
        }
    } else return dt; // no tz_options, so we're done here

    // Now we're left with a 'real' time zone, which is more complicated.
    // We have already calculated a 'localized' Unix time, as dt.unix_sec.
    // For that, We can obtain a UTC offset, subtract it and see if we get the same datetime.
    const local_offset = try UTCoffset.atUnixtime(dt.tz.?, dt.unix_sec);
    const unix_guess_1 = dt.unix_sec - local_offset.seconds_east;
    var dt_guess_1 = try Datetime.fromUnix(
        unix_guess_1,
        Duration.Resolution.second,
        .{ .tz = dt.tz.? },
    );
    dt_guess_1.nanosecond = dt.nanosecond;

    // However, we could still have an ambiguous datetime or a datetime in a gap of
    // a DST transition. To exclude that, we need the surrounding timetypes of the current one.
    const sts = try getSurroundingTimetypes(local_offset.__transition_index, dt.tz.?);

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
    const unix_guess_2 = dt.unix_sec - @as(i64, @intCast(tt_guess.?.offset));
    var dt_guess_2 = try Datetime.fromUnix(
        unix_guess_2,
        Duration.Resolution.second,
        .{ .tz = dt.tz.? },
    );
    dt_guess_2.nanosecond = dt.nanosecond;

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
                if (dt_guess_1.utc_offset.?.is_dst) return dt_guess_1 else return dt_guess_2;
            },
            1 => { // we want the DST inactive / 'late' side
                if (dt_guess_1.utc_offset.?.is_dst) return dt_guess_2 else return dt_guess_1;
            },
        }
    }

    // If we came here, either guess 1 or guess 2 is correct; guess 1 takes precedence.
    if (dt_eq_guess_1) return dt_guess_1;
    if (dt_eq_guess_2) return dt_guess_2;

    // If both guesses did NOT succeed, we have a non-existent datetime.
    // this should give an error.
    return ZdtError.NonexistentDatetime;
}

/// Make a fields struct from a datetime.
pub fn toFields(dt: *const Datetime) Fields {
    var opts: ?tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null;
    // if we don't have a tz, we might still have an offset:
    if (opts == null) opts = if (dt.utc_offset) |off| .{ .utc_offset = off } else null;

    return .{
        .year = dt.year,
        .month = dt.month,
        .day = dt.day,
        .hour = dt.hour,
        .minute = dt.minute,
        .second = dt.second,
        .nanosecond = dt.nanosecond,
        .dst_fold = dt.dst_fold,
        .tz_options = opts,
    };
}

/// Replace a datetime field.
pub fn replace(dt: *const Datetime, new_fields: OptFields) !Datetime {
    var fields = dt.toFields();
    if (new_fields.year) |v| fields.year = v;
    if (new_fields.month) |v| fields.month = v;
    if (new_fields.day) |v| fields.day = v;
    if (new_fields.hour) |v| fields.hour = v;
    if (new_fields.minute) |v| fields.minute = v;
    if (new_fields.second) |v| fields.second = v;
    if (new_fields.nanosecond) |v| fields.nanosecond = v;
    return try Datetime.fromFields(fields);
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

/// Construct a datetime from Unix time with a specific precision (time unit).
/// tz_opts allows to optionally specify a UTC offset or a time zone.
pub fn fromUnix(
    quantity: i128,
    resolution: Duration.Resolution,
    tz_opts: ?tz_options,
) ZdtError!Datetime {
    if (quantity > @as(i128, unix_s_max) * @intFromEnum(resolution) or
        quantity < @as(i128, unix_s_min) * @intFromEnum(resolution))
        return ZdtError.UnixOutOfRange;

    var _dt = Datetime{};
    if (tz_opts) |opts| switch (opts) {
        .utc_offset => _dt.utc_offset = opts.utc_offset,
        .tz => _dt.tz = opts.tz,
    };

    switch (resolution) {
        .second => {
            _dt.unix_sec = @intCast(quantity);
        },
        .millisecond => {
            _dt.unix_sec = @intCast(@divFloor(quantity, @as(i128, ms_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, ms_per_s)) * us_per_s);
        },
        .microsecond => {
            _dt.unix_sec = @intCast(@divFloor(quantity, @as(i128, us_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, us_per_s)) * ms_per_s);
        },
        .nanosecond => {
            _dt.unix_sec = @intCast(@divFloor(quantity, @as(i128, ns_per_s)));
            _dt.nanosecond = @intCast(@mod(quantity, @as(i128, ns_per_s)));
        },
    }

    try _dt.normalizeToUnix();
    return _dt;
}

/// A helper to update datetime fields so that they agree with the unix_sec internal
/// representation. Expects a "local" Unix time, to be corrected by the
/// UTC offset of the time zone (if such is supplied).
///
/// Modifies input in-place.
fn normalizeToUnix(dt: *Datetime) TzError!void {
    // "local" Unix time to get the fields right:
    var fake_unix = dt.unix_sec;
    // if a time zone is defined, this takes precedence and overwrites the UTC offset if one is specified.
    if (dt.tz) |tz_ptr| {
        dt.utc_offset = try UTCoffset.atUnixtime(tz_ptr, dt.unix_sec);
        fake_unix += dt.utc_offset.?.seconds_east;
    } else if (dt.utc_offset) |off| { // having only a UTC offset (no tz) is also fine.
        fake_unix += off.seconds_east;
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
pub fn toUnix(dt: *const Datetime, resolution: Duration.Resolution) i128 {
    switch (resolution) {
        .second => return @as(i128, dt.unix_sec),
        .millisecond => return @as(i128, dt.unix_sec) * ms_per_s + @divFloor(dt.nanosecond, us_per_s),
        .microsecond => return @as(i128, dt.unix_sec) * us_per_s + @divFloor(dt.nanosecond, ms_per_s),
        .nanosecond => return @as(i128, dt.unix_sec) * ns_per_s + dt.nanosecond,
    }
}

/// true if datetime is aware of its offset from UTC
pub fn isAware(dt: *const Datetime) bool {
    return dt.utc_offset != null;
}

/// true if no offset from UTC is defined
pub fn isNaive(dt: *const Datetime) bool {
    return dt.utc_offset == null;
}

/// returns true if a datetime is located in daylight saving time.
pub fn isDST(dt: *const Datetime) bool {
    return if (dt.utc_offset) |offset| offset.is_dst else false;
}

/// Make a datetime local to a given time zone.
///
/// 'null' can be supplied to make an aware datetime naive.
pub fn tzLocalize(dt: Datetime, opts: ?tz_options) ZdtError!Datetime {
    return Datetime.fromFields(.{
        .year = dt.year,
        .month = dt.month,
        .day = dt.day,
        .hour = dt.hour,
        .minute = dt.minute,
        .second = dt.second,
        .nanosecond = dt.nanosecond,
        .tz_options = opts,
    });
}

/// Convert datetime to another time zone. The datetime must be aware;
/// can only convert to another time zone if initial time zone is defined
pub fn tzConvert(dt: *const Datetime, opts: tz_options) ZdtError!Datetime {
    if (dt.isNaive()) return ZdtError.TzUndefined;
    return Datetime.fromUnix(
        @as(i128, dt.unix_sec) * ns_per_s + dt.nanosecond,
        Duration.Resolution.nanosecond,
        opts,
    );
}

/// Floor a datetime to a certain timespan. Creates a new datetime instance.
pub fn floorTo(dt: *const Datetime, timespan: Duration.Timespan) !Datetime {
    // any other timespan than second can lead to ambiguous or non-existent
    // datetime - therefore we need to make a new datetime
    var fields = Fields{
        .tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null,
    };
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
/// If 'null' is supplied as tz_options, naive datetime resembling UTC is returned.
pub fn now(opts: ?tz_options) ZdtError!Datetime {
    const t = std.time.nanoTimestamp();
    return try Datetime.fromUnix(@intCast(t), Duration.Resolution.nanosecond, opts);
}

/// Current UTC time is fail-safe since it contains a pre-defined time zone.
pub fn nowUTC() Datetime {
    const t = std.time.nanoTimestamp();
    return Datetime.fromUnix(
        @intCast(t),
        Duration.Resolution.nanosecond,
        .{ .utc_offset = UTCoffset.UTC },
    ) catch unreachable;
}

/// Compare two instances with respect to their Unix time.
/// Ignores the time zone - however, both datetimes must either be aware or naive.
pub fn compareUT(this: Datetime, other: Datetime) ZdtError!std.math.Order {
    // can only compare if both aware or naive, not a mix.
    if ((this.isAware() and other.isNaive()) or
        (this.isNaive() and other.isAware())) return ZdtError.CompareNaiveAware;
    return std.math.order(
        @as(i128, this.unix_sec) * ns_per_s + this.nanosecond,
        @as(i128, other.unix_sec) * ns_per_s + other.nanosecond,
    );
}

/// Compare wall time, irrespective of the time zone.
pub fn compareWall(this: Datetime, other: Datetime) !std.math.Order {
    const _this = if (this.isAware()) try this.tzLocalize(null) else this;
    const _other = if (other.isAware()) try other.tzLocalize(null) else other;
    return try Datetime.compareUT(_this, _other);
}

/// Add absolute duration to a datetime.
pub fn add(dt: *const Datetime, td: Duration) ZdtError!Datetime {
    const ns: i128 = ( //
        @as(i128, dt.unix_sec) * ns_per_s + //
        @as(i128, dt.nanosecond) + //
        td.__sec * ns_per_s + //
        td.__nsec //
    );
    const opts: ?tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null;
    return try Datetime.fromUnix(ns, Duration.Resolution.nanosecond, opts);
}

/// Subtract a duration from a datetime.
pub fn sub(dt: *const Datetime, td: Duration) ZdtError!Datetime {
    return dt.add(.{ .__sec = td.__sec * -1, .__nsec = td.__nsec });
}

/// Add a relative duration to a datetime, might include months and years.
pub fn addRelative(dt: *const Datetime, rel_delta: Duration.RelativeDelta) !Datetime {
    const abs_delta = try Duration.RelativeDelta.toDuration(.{
        .weeks = rel_delta.weeks,
        .days = rel_delta.days,
        .hours = rel_delta.hours,
        .minutes = rel_delta.minutes,
        .seconds = rel_delta.seconds,
        .nanoseconds = rel_delta.nanoseconds,
    });
    var result: Datetime = try dt.add(abs_delta);

    var m_off: i32 = @intCast(rel_delta.months + rel_delta.years * 12);
    if (rel_delta.negative) m_off *= -1;
    m_off += result.month;

    result.year = @intCast(@as(i32, result.year) + @divFloor(m_off, 12));
    const new_month: u8 = @intCast(@mod(m_off, 12));
    if (new_month <= 0) {
        result.month = new_month + 12;
        result.year -= 1;
    } else result.month = new_month;

    const days_in_month = cal.daysInMonth(result.month, cal.isLeapYear(result.year));
    if (result.day > days_in_month) result.day = days_in_month;

    return try Datetime.fromFields(.{
        .year = result.year,
        .month = result.month,
        .day = result.day,
        .hour = result.hour,
        .minute = result.minute,
        .second = result.second,
        .nanosecond = result.nanosecond,
        .dst_fold = result.dst_fold,
        .tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null,
    });
}

/// Calculate the absolute difference between two datetimes, independent of the time zone.
/// Excludes leap seconds.
/// To get the difference in leap seconds, see Datetime.diffLeap().
///
/// Result is (this - other) as a Duration.
pub fn diff(this: Datetime, other: Datetime) Duration {
    var s: i64 = this.unix_sec - other.unix_sec;
    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Calculate wall time difference between two aware datetimes.
/// If one of the datetimes is naive (no time zone specified), this is considered an error.
///
/// Result is ('this' wall time - 'other' wall time) as a Duration.
pub fn diffWall(this: Datetime, other: Datetime) !Duration {
    if (this.isNaive() or other.isNaive()) return error.TzUndefined;
    if (this.utc_offset == null or other.utc_offset == null) return error.TzUndefined;

    var s: i64 = ((this.unix_sec - other.unix_sec) +
        (this.utc_offset.?.seconds_east - other.utc_offset.?.seconds_east));

    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Validate a datetime in terms of leap seconds;
/// Returns an error if the datetime has seconds == 60 but is NOT a leap second datetime.
//
// TODO : might be private
pub fn validateLeap(this: *const Datetime) !void {
    if (this.second != 60) return;
    if (cal.mightBeLeap(this.unix_sec)) return;
    return error.SecondOutOfRange;
}

/// Difference in leap seconds between two datetimes.
/// To get the absolute time difference between two datetimes including leap seconds,
/// add the result of diffleap() to that of diff().
///
/// UTC is assumed for naive datetime.
///
/// Result is (leap seconds of 'this' - leap seconds of 'other') as a Duration.
pub fn diffLeap(this: Datetime, other: Datetime) Duration {
    const this_leap: i16 = @as(i16, cal.leapCorrection(this.unix_sec));
    const other_leap: i16 = @as(i16, cal.leapCorrection(other.unix_sec));
    return Duration.fromTimespanMultiple(
        this_leap - other_leap,
        Duration.Timespan.second,
    );
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
    var isocal = ISOCalendar{ .isoyear = dt.year, .isoweek = 0, .isoweekday = @truncate(dow) };
    if (w > weeks) {
        isocal.isoweek = 1;
        return isocal;
    }
    if (w < 1) {
        isocal.isoweek = cal.weeksPerYear(dt.year - 1);
        isocal.isoyear = dt.year - 1;
        return isocal;
    }
    isocal.isoweek = @truncate(w);
    return isocal;
}

/// Parse a string to a datetime.
pub fn fromString(string: []const u8, directives: []const u8) !Datetime {
    return try str.tokenizeAndParse(string, directives);
}

/// Make a datetime from a string with an ISO8601-compatible format.
pub fn fromISO8601(string: []const u8) !Datetime {
    // 9 digits of fractional seconds and ±hh:mm:ss UTC offset: 38 characters
    if (string.len > 38)
        return error.InvalidFormat;
    // last character must be Z (UTC) or a digit, otherwise the input is not ISO8601-compatible
    if (string[string.len - 1] == 'Z' or std.ascii.isDigit(string[string.len - 1])) {
        var idx: usize = 0; // assume datetime starts at beginning of string
        return try Datetime.fromFields(try str.parseISO8601(string, &idx));
    }
    return error.InvalidFormat;
}

/// Format a datetime into a string
pub fn toString(dt: Datetime, directives: []const u8, writer: anytype) !void {
    return try str.tokenizeAndPrint(&dt, directives, writer);
}

/// IANA identifier or POSIX string, empty string if undefined
pub fn tzName(dt: *const Datetime) []const u8 {
    if (dt.tz) |tz_ptr| return tz_ptr.name();
    if (dt.utc_offset) |*off| {
        if (std.meta.eql(off.*, UTCoffset.UTC)) return off.designation();
    }
    return "";
}

/// Time zone abbreviation, such as 'CET' for Europe/Berlin zone in winter
pub fn tzAbbreviation(dt: *const Datetime) []const u8 {
    if (dt.utc_offset) |*off| {
        return if (std.mem.eql(u8, off.designation(), "UTC")) "Z" else off.designation();
    }
    return "";
}

/// Formatted printing for UTC offset
pub fn formatOffset(
    dt: Datetime,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    return if (dt.isAware()) dt.utc_offset.?.format("", options, writer);
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

    if (dt.utc_offset) |off| try off.format("", .{ .fill = ':', .precision = 1 }, writer);
}

/// Surrounding timetypes at a given transition index. This index might be
/// negative to indicate out-of-range values.
pub fn getSurroundingTimetypes(idx: i32, _tz: *const Timezone) ![3]?*tzif.Timetype {
    switch (_tz.rules) {
        .tzif => {
            var surrounding = [3]?*tzif.Timetype{ null, null, null };
            if (idx > 0) {
                surrounding[1] = _tz.rules.tzif.transitions[@as(u64, @intCast(idx))].timetype;
            }
            if (idx >= 1) {
                surrounding[0] = _tz.rules.tzif.transitions[@as(u64, @intCast(idx - 1))].timetype;
            }
            if (idx > 0 and idx < _tz.rules.tzif.transitions.len - 1) {
                surrounding[2] = _tz.rules.tzif.transitions[@as(u64, @intCast(idx + 1))].timetype;
            }
            return surrounding;
        },
        .posixtz => return TzError.NotImplemented,
        .utc => return TzError.NotImplemented,
    }
}
