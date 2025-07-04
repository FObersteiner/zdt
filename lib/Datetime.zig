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

const FormatError = @import("./errors.zig").FormatError;
const RangeError = @import("./errors.zig").RangeError;
const TzError = @import("./errors.zig").TzError;
const ZdtError = @import("./errors.zig").ZdtError;

/// Minimum year that can be represented. The value must be positive to
/// avoid ambiguities when parsing datetime strings.
pub const min_year: i16 = 0;

/// Maximum year that can be represented. The value is limited to 4 digits
/// to avoid ambiguities when parsing datetime strings.
pub const max_year: i16 = 9999;

/// 0000-01-01 00:00:00
pub const unix_s_min: i64 = -719528 * @as(i64, s_per_day);

/// 9999-12-31 23:59:59
pub const unix_s_max: i64 = (2932897 * @as(i64, s_per_day)) - 1;

/// The Unix epoch
pub const epoch = Datetime{ .year = 1970, .unix_sec = 0, .utc_offset = UTCoffset.UTC };

/// The current century
pub const century: i16 = 2000;

/// Microseconds between 1970-01-01 and 2000-01-01
pub const us_from_epoch_to_y2k: i64 = 946_684_800_000_000;

const s_per_minute: u8 = 60;
const s_per_hour: u16 = 3600;
const s_per_day: u32 = 86400;
const ms_per_s: u16 = 1_000;
const us_per_s: u32 = 1_000_000;
const ns_per_s: u32 = 1_000_000_000;

const Datetime = @This();

/// Year. Do not modify directly.
year: i16 = 1, // [-32768, 32676]

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
/// Can for instance be used to get locale-independent English names.
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

    pub fn nameToInt(name: []const u8) RangeError!u8 {
        inline for (std.meta.fields(Weekday)) |f| {
            if (std.mem.eql(u8, name, f.name)) return f.value;
        }
        return RangeError.DayOutOfRange;
    }

    pub fn nameShortToInt(name: []const u8) RangeError!u8 {
        inline for (std.meta.fields(Weekday)) |f| {
            if (std.mem.eql(u8, name, f.name[0..3])) return f.value;
        }
        return RangeError.DayOutOfRange;
    }
};

/// Enum-representation of a month, with January being 1.
/// Can for instance be used to get locale-independent English names.
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

    pub fn nameToInt(name: []const u8) RangeError!u8 {
        inline for (std.meta.fields(Month)) |f| {
            if (std.mem.eql(u8, name, f.name)) return f.value;
        }
        return RangeError.MonthOutOfRange;
    }

    pub fn nameShortToInt(name: []const u8) RangeError!u8 {
        inline for (std.meta.fields(Month)) |f| {
            if (std.mem.eql(u8, name, f.name[0..3])) return f.value;
        }
        return RangeError.MonthOutOfRange;
    }
};

/// Implementation of the ISO8601 leap week calendar system.
pub const ISOCalendar = struct {
    isoyear: i16,
    isoweek: u8, // [1, 53]
    isoweekday: u8, // [1, 7]

    // Date of the first day of given ISO year
    fn yearStartDate(iso_year: i16) ZdtError!Datetime {
        const fourth_jan = try Datetime.fromFields(.{ .year = iso_year, .month = 1, .day = 4 });
        return fourth_jan.sub(
            Duration.fromTimespanMultiple(
                @as(u16, fourth_jan.weekdayIsoNumber() - 1),
                Duration.Timespan.day,
            ),
        );
    }

    /// Gregorian calendar date for given ISOCalendar
    pub fn toDatetime(isocal: ISOCalendar) ZdtError!Datetime {
        const year_start = try yearStartDate(isocal.isoyear);
        return year_start.add(
            Duration.fromTimespanMultiple(
                @as(u16, isocal.isoweekday - 1) + @as(u16, isocal.isoweek - 1) * 7,
                Duration.Timespan.day,
            ),
        );
    }

    pub fn fromString(string: []const u8) FormatError!ISOCalendar {
        if (string.len < 10) return FormatError.InvalidFormat;
        if (string[4] != '-' or std.ascii.toLower(string[5]) != 'w' or string[8] != '-')
            return FormatError.InvalidFormat;
        return .{
            .isoyear = try std.fmt.parseInt(i16, string[0..4], 10),
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
            "{s}{d:0>4}-W{d:0>2}-{d}",
            .{
                if (calendar.isoyear < 0) "-" else "",
                @abs(calendar.isoyear),
                calendar.isoweek,
                calendar.isoweekday,
            },
        );
    }
};

// Helper for the helper...
const tzOpts = enum {
    tz,
    utc_offset,
};

/// Helper to specify either a time zone (from TZif or POSIX TZ) or a UTC offset
pub const tz_options = union(tzOpts) {
    tz: *const Timezone,
    utc_offset: UTCoffset,
};

/// The fields of a datetime instance.
pub const Fields = struct {
    year: i16 = 1, // [1, 9999]
    month: u8 = 1, // [1, 12]
    day: u8 = 1, // [1, 32]
    hour: u8 = 0, // [0, 23]
    minute: u8 = 0, // [0, 59]
    second: u8 = 0, // [0, 60]
    nanosecond: u32 = 0, // [0, 999999999]
    dst_fold: ?u1 = null,
    tz_options: ?tz_options = null,

    pub fn validate(fields: Fields) RangeError!void {
        if (fields.month > 12 or fields.month < 1) return RangeError.MonthOutOfRange;
        const max_days = cal.daysInMonth(@truncate(fields.month), cal.isLeapYear(fields.year));
        if (fields.day > max_days or fields.day < 1) return RangeError.DayOutOfRange;
        if (fields.hour > 23) return RangeError.HourOutOfRange;
        if (fields.minute > 59) return RangeError.MinuteOutOfRange;
        if (fields.second > 60) return RangeError.SecondOutOfRange;
        if (fields.nanosecond > 999999999) return RangeError.NanosecondOutOfRange;
    }
};

/// Datetime fields without timezone and UTC offset. All fields optional and undefined by default.
/// Helper for `Datetime.replace()`.
pub const OptFields = struct {
    year: ?i16 = null,
    month: ?u8 = null,
    day: ?u8 = null,
    hour: ?u8 = null,
    minute: ?u8 = null,
    second: ?u8 = null,
    nanosecond: ?u32 = null,
};

/// Make a valid datetime from fields.
/// Full validation is always performed, not just in debug builds.
pub fn fromFields(fields: Fields) ZdtError!Datetime {
    _ = try fields.validate();

    const d: i32 = cal.dateToRD(.{ .year = fields.year, .month = fields.month, .day = fields.day });
    // Note : need to truncate seconds to 59 so that Unix time is 'correct'
    const s: u8 = if (fields.second == 60) 59 else fields.second;
    var dt = Datetime{
        .year = fields.year,
        .month = fields.month,
        .day = fields.day,
        .hour = fields.hour,
        .minute = fields.minute,
        .second = fields.second,
        .nanosecond = fields.nanosecond,
        .unix_sec = ( //
            @as(i64, d) * s_per_day +
                @as(u32, fields.hour) * s_per_hour +
                @as(u16, fields.minute) * s_per_minute + s //
        ),
    };

    // verify that provided leap second datetime is valid
    if (dt.second == 60) try dt.validateLeap();

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
    const local_offset: UTCoffset = try UTCoffset.atUnixtime(dt.tz.?, dt.unix_sec);

    const unix_guess_1 = dt.unix_sec - local_offset.seconds_east;
    var dt_guess_1 = try Datetime.fromUnix(
        unix_guess_1,
        Duration.Resolution.second,
        .{ .tz = dt.tz.? },
    );
    dt_guess_1.nanosecond = dt.nanosecond;

    // However, we could still have
    // - an ambiguous datetime or
    // - a datetime in a gap of a DST transition.
    // To exclude that, we need the surrounding timetypes (UTC offsets) of the current one.
    const sts = try getSurroundingTimetypes(local_offset, dt.tz.?);

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
pub fn replace(dt: *const Datetime, new_fields: OptFields) ZdtError!Datetime {
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
/// `tz_opts` allows to optionally specify a UTC offset or a time zone.
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

    try _dt.normalizeToUnix(); // in-place update!
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
    const ymd: cal.Date = cal.rdToDate(days);
    dt.year = @truncate(ymd.year);
    dt.month = @intCast(ymd.month);
    dt.day = @intCast(ymd.day);
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
/// `null` can be supplied to make an aware datetime naive.
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
    if (dt.isNaive()) return TzError.TzUndefined;
    return Datetime.fromUnix(
        @as(i128, dt.unix_sec) * ns_per_s + dt.nanosecond,
        Duration.Resolution.nanosecond,
        opts,
    );
}

/// Floor a datetime to a certain timespan. Creates a new datetime instance.
pub fn floorTo(dt: *const Datetime, timespan: Duration.Timespan) ZdtError!Datetime {
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
    return try Datetime.fromUnix(
        std.time.nanoTimestamp(),
        Duration.Resolution.nanosecond,
        opts,
    );
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

/// Check if a datetime is within a leap year
pub fn isLeapYear(dt: *const Datetime) bool {
    return cal.isLeapYear(dt.year);
}

/// Check if a datetime is within February of a leap year
pub fn isLeapMonth(dt: *const Datetime) bool {
    return cal.isLeapMonth(dt.year, dt.month);
}

/// Compare two instances with respect to their Unix time.
/// Ignores the time zone - however, both datetimes must either be aware or naive.
pub fn compareUT(this: Datetime, other: Datetime) TzError!std.math.Order {
    // can only compare if both aware or naive, not a mix.
    if ((this.isAware() and other.isNaive()) or
        (this.isNaive() and other.isAware())) return TzError.CompareNaiveAware;
    return std.math.order(
        @as(i128, this.unix_sec) * ns_per_s + this.nanosecond,
        @as(i128, other.unix_sec) * ns_per_s + other.nanosecond,
    );
}

/// Compare wall time, irrespective of the time zone.
pub fn compareWall(this: Datetime, other: Datetime) ZdtError!std.math.Order {
    const _this = if (this.isAware()) try this.tzLocalize(null) else this;
    const _other = if (other.isAware()) try other.tzLocalize(null) else other;
    return try Datetime.compareUT(_this, _other);
}

/// Add absolute duration to a datetime.
pub fn add(dt: *const Datetime, td: Duration) ZdtError!Datetime {
    const ns: i128 = ( //
        @as(i128, dt.unix_sec) * ns_per_s + @as(i128, dt.nanosecond) + //
            td.asNanoseconds() //
    );
    const opts: ?tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null;
    return try Datetime.fromUnix(ns, Duration.Resolution.nanosecond, opts);
}

/// Subtract a duration from a datetime.
pub fn sub(dt: *const Datetime, td: Duration) ZdtError!Datetime {
    return dt.add(.{ .__sec = td.__sec * -1, .__nsec = td.__nsec });
}

/// Add a duration which might include months and years to a datetime.
///
/// Arithmetic is wall-time arithmetic; e.g. adding a day across a DST transition
/// would not change the hour of the resulting datetime.
///
/// Returns an error if the resulting datetime would be a non-existent datetime (DST gap).
/// A resulting ambiguous datetime (DST fold) is resolved if the `dst_fold` attribute
/// is set. If not (= null), this function will also return an error.
pub fn addRelative(dt: *const Datetime, rel_delta: Duration.RelativeDelta) ZdtError!Datetime {
    const nrd = rel_delta.normalize();
    const new_time = if (nrd.negative) // [hours, minutes, seconds, nanoseconds, day_changed]
        subTimes(
            [4]u32{ dt.hour, dt.minute, dt.second, dt.nanosecond },
            [4]u32{ nrd.hours, nrd.minutes, nrd.seconds, nrd.nanoseconds },
        )
    else
        addTimes(
            [4]u32{ dt.hour, dt.minute, dt.second, dt.nanosecond },
            [4]u32{ nrd.hours, nrd.minutes, nrd.seconds, nrd.nanoseconds },
        );

    const days_off: i32 = @intCast(nrd.days + nrd.weeks * 7 + new_time[4]);
    var rd_day: i32 = cal.dateToRD(.{ .year = dt.year, .month = dt.month, .day = dt.day });
    rd_day = if (nrd.negative) rd_day - days_off else rd_day + days_off;
    const new_date: cal.Date = cal.rdToDate(rd_day);
    var result: Fields = .{
        .year = @truncate(new_date.year),
        .month = @truncate(new_date.month),
        .day = @truncate(new_date.day),
        .hour = @truncate(new_time[0]),
        .minute = @truncate(new_time[1]),
        .second = @truncate(new_time[2]),
        .nanosecond = new_time[3],
        .dst_fold = dt.dst_fold,
        .tz_options = if (dt.tz) |tz_ptr| .{ .tz = tz_ptr } else null,
    };

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

    return try Datetime.fromFields(result);
}

/// Calculate the absolute difference between two datetimes, independent of the time zone.
/// Excludes leap seconds.
/// To get the difference in leap seconds, see `Datetime.diffLeap()`.
///
/// Result is (this - other) as a Duration.
pub fn diff(this: Datetime, other: Datetime) Duration {
    var s: i64 = this.unix_sec - other.unix_sec;
    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    // We use 'addClip' here to avoid the error union from the normal 'add'.
    // Since we add < 1_000_000_000 ns, the Duration type will never overflow
    // and the result won't become incorrect from clipping.
    return (Duration.fromTimespanMultiple(s, .second)
        .addClip(Duration.fromTimespanMultiple(ns, .nanosecond)));
}

/// Calculate wall time difference between two aware datetimes.
/// If one of the datetimes is naive (no time zone specified), this is considered an error.
///
/// Result is (`this` wall time - `other` wall time) as a Duration.
pub fn diffWall(this: Datetime, other: Datetime) TzError!Duration {
    if (this.isNaive() or other.isNaive()) return TzError.TzUndefined;
    if (this.utc_offset == null or other.utc_offset == null) return TzError.TzUndefined;

    var s: i64 = ((this.unix_sec - other.unix_sec) +
        (this.utc_offset.?.seconds_east - other.utc_offset.?.seconds_east));

    var ns: i32 = @as(i32, @intCast(this.nanosecond)) - @as(i32, @intCast(other.nanosecond));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    // We use 'addClip' here to avoid the error union from the normal 'add'.
    // Since we add < 1_000_000_000 ns, the Duration type will never overflow
    // and the result won't become incorrect from clipping.
    return (Duration.fromTimespanMultiple(s, .second)
        .addClip(Duration.fromTimespanMultiple(ns, .nanosecond)));
}

/// Validate a datetime in terms of leap seconds;
/// Returns an error if the datetime has seconds >= 60 but is NOT a leap second datetime.
pub fn validateLeap(this: *const Datetime) RangeError!void {
    if (this.second < 60) return;
    if (cal.mightBeLeap(this.unix_sec)) return;
    return RangeError.SecondOutOfRange;
}

/// Difference in leap seconds between two datetimes.
/// To get the absolute time difference between two datetimes including leap seconds,
/// add the result of `diffLeap()` to that of `diff()`.
///
/// UTC is assumed for naive datetime.
///
/// Result is (leap seconds of `this` - leap seconds of `other`) as a Duration.
pub fn diffLeap(this: Datetime, other: Datetime) Duration {
    const this_leap: i16 = @as(i16, cal.leapCorrection(this.unix_sec));
    const other_leap: i16 = @as(i16, cal.leapCorrection(other.unix_sec));
    return Duration.fromTimespanMultiple(
        this_leap - other_leap,
        Duration.Timespan.second,
    );
}

/// Day of the year starting with `1 == yyyy-01-01` (strftime/strptime: `%j`).
pub fn dayOfYear(dt: Datetime) u16 {
    return cal.dayOfYear(dt.year, dt.month, dt.day);
}

/// Number of ISO weeks per year, same as weeksPerYear but taking a datetime instance.
pub fn weeksInYear(dt: Datetime) u8 {
    return cal.weeksPerYear(dt.year);
}

/// Day of the week as an enum value; Sun as first day of the week.
pub fn weekday(dt: Datetime) Weekday {
    return std.meta.intToEnum(Weekday, dt.weekdayNumber()) catch unreachable;
}

pub fn monthEnum(dt: Datetime) Month {
    return std.meta.intToEnum(Month, dt.month) catch unreachable;
}

/// Number of the weekday starting at 0 == Sunday (strftime/strptime: `%w`).
pub fn weekdayNumber(dt: Datetime) u8 {
    return cal.weekdayFromUnixdays(cal.dateToRD(.{ .year = dt.year, .month = dt.month, .day = dt.day }));
}

/// ISO-number of the weekday, starting at 1 == Monday (strftime/strptime: `%u`).
pub fn weekdayIsoNumber(dt: Datetime) u8 {
    return cal.ISOweekdayFromUnixdays(cal.dateToRD(.{ .year = dt.year, .month = dt.month, .day = dt.day }));
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
    return dt.add(offset) catch unreachable; // might fail on weird corner-cases!
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
    return dt.add(offset) catch unreachable; // might fail on weird corner-cases!
}

/// nth weekday of given month and year, returned as a Datetime.
/// nth must be in range [1..5]; although 5 might return an error for certain year/month combinations.
pub fn nthWeekday(year: i16, month: u8, wd: Weekday, nth: u8) ZdtError!Datetime {
    if (nth > 5 or nth == 0) return RangeError.DayOutOfRange;
    var dt = try Datetime.fromFields(.{ .year = year, .month = month });
    if (dt.weekday() != wd) dt = dt.nextWeekday(wd);
    if (nth == 1) return dt;
    dt = try dt.add(Duration.fromTimespanMultiple(7 * (nth - 1), Duration.Timespan.day));
    if (dt.month != month) return RangeError.DayOutOfRange;
    return dt;
}

/// Week number of the year (Sunday as the first day of the week) as returned from
/// strftime's `%U`
pub fn weekOfYearSun(dt: Datetime) u8 {
    const doy = dt.dayOfYear() - 1; // [0..365]
    const dow = dt.weekdayNumber();
    return @truncate(@divFloor(doy + 7 - dow, 7));
}

/// Week number of the year (Monday as the first day of the week) as returned from
/// strftime's `%W`
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
pub fn fromString(string: []const u8, directives: []const u8) ZdtError!Datetime {
    if (string.len == 0 or directives.len == 0) return FormatError.EmptyString;
    return try str.tokenizeAndParse(string, directives);
}

/// Make a datetime from a string with an ISO8601-compatible format.
pub fn fromISO8601(string: []const u8) ZdtError!Datetime {
    // 9 digits of fractional seconds and ±hh:mm:ss UTC offset: 38 characters
    if (string.len > 38)
        return FormatError.InvalidFormat;
    // last character must be Z (UTC) or a digit, otherwise the input is not ISO8601-compatible
    if (string[string.len - 1] == 'Z' or std.ascii.isDigit(string[string.len - 1])) {
        var idx: usize = 0; // assume datetime starts at beginning of string
        return try Datetime.fromFields(try str.parseISO8601(string, &idx));
    }
    return FormatError.InvalidFormat;
}

/// Format a datetime into a string.
pub fn toString(dt: Datetime, directives: []const u8, writer: anytype) anyerror!void {
    return try str.tokenizeAndPrint(&dt, directives, writer);
}

/// IANA identifier or POSIX string, empty string if undefined.
pub fn tzName(dt: *const Datetime) []const u8 {
    if (dt.tz) |tz_ptr| return tz_ptr.name();
    if (dt.utc_offset) |*off| {
        if (std.meta.eql(off.*, UTCoffset.UTC)) return off.designation();
    }
    return "";
}

/// Time zone abbreviation, such as 'CET' for Europe/Berlin zone in winter.
/// Empty string if undefined.
pub fn tzAbbreviation(dt: *const Datetime) []const u8 {
    if (dt.utc_offset) |*off| {
        return if (std.mem.eql(u8, off.designation(), "UTC")) "Z" else off.designation();
    }
    return "";
}

/// Formatted printing for UTC offset.
pub fn formatOffset(
    dt: Datetime,
    options: std.fmt.FormatOptions,
    writer: anytype,
) anyerror!void {
    return if (dt.isAware()) dt.utc_offset.?.format("", options, writer);
}

/// Calculate the date of Easter (Gregorian calendar).
pub fn EasterDate(year: i16) ZdtError!Datetime {
    const easterdate = cal.gregorianEaster(year);
    return try Datetime.fromFields(.{
        .year = @truncate(easterdate.year),
        .month = @truncate(easterdate.month),
        .day = @truncate(easterdate.day),
    });
}

/// Julian calendar Easter date.
///
/// Note that from year 1900 to 2099, 13 days must be added to the Julian
/// calendar date to get the equivalent Gregorian calendar date.
pub fn EasterDateJulian(year: i16) ZdtError!Datetime {
    const ymd: cal.Date = cal.julianEaster(year);
    return try Datetime.fromFields(.{
        .year = @truncate(ymd.year),
        .month = @truncate(ymd.month),
        .day = @truncate(ymd.day),
    });
}

/// Custom printing for the Datetime struct, to be used e.g. in std.debug.print.
/// Defaults to ISO8601 / RFC3339nano format.
///
/// Nanoseconds are displayed if not zero. To get milli- or microsecond precision,
/// use formatting directive `{s:.3}` (ms) or `{s:.6}` (us).
///
/// If a formatting directive other than 's' or none is provided, the method
/// tries to interpret it as regular datetime formatting directive, like the ones
/// used in `Datetime.toString`.
///
/// For example
/// ```
/// std.debug.print("{%Y-%m}", .{dt});
/// //  ...would evaluate to
/// "2025-03"
/// ```
pub fn format(
    dt: Datetime,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) anyerror!void { // have to use 'anyerror' here due to the 'anytype' writer
    if (!(std.mem.eql(u8, fmt, "s") or fmt.len == 0))
        return try str.tokenizeAndPrint(&dt, fmt, writer);

    try writer.print(
        "{s}{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}",
        .{ if (dt.year < 0) "-" else "", @abs(dt.year), dt.month, dt.day, dt.hour, dt.minute, dt.second },
    );

    if (options.precision) |p| switch (p) {
        0 => {},
        1 => try writer.print(".{d:0>1}", .{dt.nanosecond / 1_000_000_00}),
        2 => try writer.print(".{d:0>2}", .{dt.nanosecond / 1_000_000_0}),
        3 => try writer.print(".{d:0>3}", .{dt.nanosecond / 1_000_000}),
        4 => try writer.print(".{d:0>4}", .{dt.nanosecond / 1_000_00}),
        5 => try writer.print(".{d:0>5}", .{dt.nanosecond / 1_000_0}),
        6 => try writer.print(".{d:0>6}", .{dt.nanosecond / 1_000}),
        7 => try writer.print(".{d:0>7}", .{dt.nanosecond / 100}),
        8 => try writer.print(".{d:0>8}", .{dt.nanosecond / 10}),
        9 => try writer.print(".{d:0>9}", .{dt.nanosecond}),
        else => if (dt.nanosecond != 0) try writer.print(".{d:0>9}", .{dt.nanosecond}),
    } else if (dt.nanosecond != 0) try writer.print(".{d:0>9}", .{dt.nanosecond});

    if (dt.utc_offset) |off| try off.format("", .{ .fill = ':', .precision = 1 }, writer);
}

/// Surrounding timetypes at a given transition index. This index might be
/// negative to indicate out-of-range values.
fn getSurroundingTimetypes(local_offset: UTCoffset, _tz: *const Timezone) TzError![3]?tzif.Timetype {
    const idx = local_offset.__transition_index;
    var surrounding = [3]?tzif.Timetype{ null, null, null };
    const dummy: [6:0]u8 = [6:0]u8{ 0, 0, 0, 0, 0, 0 };

    switch (_tz.rules) {
        .tzif => {
            if (idx > 0)
                surrounding[1] = _tz.rules.tzif.timetypes[
                    _tz.rules.tzif.transitions[
                        @as(u64, @intCast(idx))
                    ].timetype_idx
                ];
            if (idx >= 1)
                surrounding[0] = _tz.rules.tzif.timetypes[
                    _tz.rules.tzif.transitions[
                        @as(u64, @intCast(idx - 1))
                    ].timetype_idx
                ];
            if (idx > 0 and idx < _tz.rules.tzif.transitions.len - 1)
                surrounding[2] = _tz.rules.tzif.timetypes[
                    _tz.rules.tzif.transitions[
                        @as(u64, @intCast(idx + 1))
                    ].timetype_idx
                ];
            return surrounding;
        },
        .tzif_fixedsize => {
            if (idx > 0)
                surrounding[1] = _tz.rules.tzif_fixedsize.__timetypes_data[
                    _tz.rules.tzif_fixedsize.__transitions_data[
                        @as(u64, @intCast(idx))
                    ].timetype_idx
                ];
            if (idx >= 1)
                surrounding[0] = _tz.rules.tzif_fixedsize.__timetypes_data[
                    _tz.rules.tzif_fixedsize.__transitions_data[
                        @as(u64, @intCast(idx - 1))
                    ].timetype_idx
                ];
            if (idx > 0 and idx < _tz.rules.tzif_fixedsize.n_transitions - 1)
                surrounding[2] = _tz.rules.tzif_fixedsize.__timetypes_data[
                    _tz.rules.tzif_fixedsize.__transitions_data[
                        @as(u64, @intCast(idx + 1))
                    ].timetype_idx
                ];
            return surrounding;
        },
        .posixtz => {
            if (_tz.rules.posixtz.dst_offset) |dst_offset| { // do we have DST at all ?
                if (local_offset.is_dst) {
                    surrounding[0] = (tzif.Timetype{ .offset = _tz.rules.posixtz.std_offset, .flags = 2, .name_data = dummy });
                    surrounding[1] = (tzif.Timetype{ .offset = dst_offset, .flags = 1, .name_data = dummy });
                    surrounding[2] = (tzif.Timetype{ .offset = _tz.rules.posixtz.std_offset, .flags = 2, .name_data = dummy });
                } else {
                    surrounding[0] = (tzif.Timetype{ .offset = dst_offset, .flags = 1, .name_data = dummy });
                    surrounding[1] = (tzif.Timetype{ .offset = _tz.rules.posixtz.std_offset, .flags = 2, .name_data = dummy });
                    surrounding[2] = (tzif.Timetype{ .offset = dst_offset, .flags = 1, .name_data = dummy });
                }
            }
            // implicit 'else':
            // if we do not have DST, are not surrounding timetypes
            return surrounding;
        },
        .utc => return TzError.NotImplemented,
    }
}

// t1, t2: [hour, minute, second, nanosecond]
// returns:  [hour, minute, second, nanosecond, day_change(0 or 1)]
fn addTimes(t1: [4]u32, t2: [4]u32) [5]u32 {
    var new_sec: u32 = t1[2] + t2[2];
    var new_ns: u32 = t1[3] + t2[3];
    if (new_ns > 1_000_000_000) {
        new_sec += 1;
        new_ns %= 1_000_000_000;
    }
    const min_add = new_sec / 60;
    new_sec %= 60;

    var new_min: u32 = t1[1] + t2[1] + min_add;
    const h_add = new_min / 60;
    new_min %= 60;

    var new_h: u32 = t1[0] + t2[0] + h_add;
    const day_change: bool = new_h >= 24;
    new_h %= 24;

    return [5]u32{ new_h, new_min, new_sec, new_ns, @intFromBool(day_change) };
}

// t1, t2: [hour, minute, second, nanosecond]
// returns:  [hour, minute, second, nanosecond, day_change(0 or 1)]
fn subTimes(t1: [4]u32, t2: [4]u32) [5]u32 {
    var _t1 = [4]i32{
        @intCast(t1[0]), @intCast(t1[1]), @intCast(t1[2]), @intCast(t1[3]),
    };

    if (_t1[3] < t2[3]) {
        _t1[3] += 1_000_000_000;
        _t1[2] -= 1;
    }

    if (_t1[2] < t2[2]) {
        _t1[1] -= 1;
        _t1[2] += 60;
    }

    if (_t1[1] < t2[1]) {
        _t1[0] -= 1;
        _t1[1] += 60;
    }

    const new_ns: u32 = @intCast(_t1[3] - @as(i32, @intCast(t2[3])));
    const new_sec: u32 = @intCast(_t1[2] - @as(i32, @intCast(t2[2])));
    const new_min: u32 = @intCast(_t1[1] - @as(i32, @intCast(t2[1])));
    var new_h: i32 = _t1[0] - @as(i32, @intCast(t2[0]));
    const day_change = if (new_h < 0) true else false;
    if (day_change) new_h += 24;

    return [5]u32{ @intCast(new_h), new_min, new_sec, new_ns, @intFromBool(day_change) };
}

/// postgres-specific constants
const pg_oids = struct {
    const timestamp_oid = 1114;
    const timestamptz_oid = 1184;
};

/// Make a datetime from postgres raw data / 8 bytes representing an i64 (big endian).
pub fn fromPgzRow(data: []const u8, oid: i32) !Datetime {
    assert(data.len >= 8);
    assert(oid == pg_oids.timestamp_oid or oid == pg_oids.timestamptz_oid);
    const millenium_micros: i128 = std.mem.readInt(i64, data[0..8], .big);
    // PostgreSQL stores times from the 2k millenium instead of the Unix epoch.
    const micros: i128 = millenium_micros + us_from_epoch_to_y2k;

    return fromUnix(micros, .microsecond, .{ .tz = &Timezone.UTC });
}
