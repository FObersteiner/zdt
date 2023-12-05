//! datetime in Zig
const std = @import("std");
pub const cal = @import("calendar.zig");
pub const zone = @import("timezone.zig");

// limit the range to make calculations a bit easier
pub const MIN_YEAR: u14 = 1; // r.d.; 0001-01-01
pub const MAX_YEAR: u14 = 9999;
pub const UNIX_s_MIN: i72 = -62135596800;
pub const UNIX_s_MAX: i72 = 253402300799;

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

const s_per_minute: u6 = 60;
const s_per_hour: u12 = 3600;
const s_per_day: u17 = 86400;
const ms_per_s: u10 = 1_000;
const us_per_s: u20 = 1_000_000;
const ns_per_s: u30 = 1_000_000_000;

/// a helper struct to provide default values for a datetime instance
pub const datetime_fields = struct {
    year: u14 = 1, // [1, 9999]
    month: u4 = 1, // [1, 12]
    day: u5 = 1, // [1, 32]
    hour: u5 = 0, // [0, 23]
    minute: u6 = 0, // [0, 59]
    second: u6 = 0, // [0, 60]
    nanosecond: u30 = 0, // [0, 999999999]
    tzinfo: ?zone.Tz = null,

    pub fn validate(self: datetime_fields) RangeError!void {
        if (self.year > MAX_YEAR or self.year < MIN_YEAR) return RangeError.YearOutOfRange;
        if (self.month > 12 or self.month < 1) return RangeError.MonthOutOfRange;
        const max_days = cal.days_in_month(self.month, std.time.epoch.isLeapYear(self.year));
        if (self.day > max_days or self.day < 1) return RangeError.DayOutOfRange;
        if (self.hour > 23) return RangeError.HourOutOfRange;
        if (self.minute > 59) return RangeError.MinuteOutOfRange;
        if (self.second > 59) return RangeError.SecondOutOfRange; // NOTE : no leap seconds for now
        if (self.nanosecond > 999999999) return RangeError.NanosecondOutOfRange;
    }
};

pub const Timeunit = enum(u30) {
    second = 1,
    nanosecond = 1_000_000_000,
};

pub const Datetime = struct {
    year: u14 = 1, // [1, 9999]
    month: u4 = 1, // [1, 12]
    day: u5 = 1, // [1, 32]
    hour: u5 = 0, // [0, 23]
    minute: u6 = 0, // [0, 59]
    second: u6 = 0, // [0, 60]
    nanosecond: u30 = 0, // [0, 999999999]
    tzinfo: ?zone.Tz = null,

    // Seconds since the Unix epoch as internal, serial representation.
    // This must always refer to UTC; there is no such thing as 'local' Unix time.
    __unix: i48 = UNIX_s_MIN, // [unix_ns_min, unix_ns_max]

    pub fn from_fields(fields: datetime_fields) RangeError!Datetime {
        _ = try fields.validate();
        if (fields.tzinfo != null) {
            // TODO:  handle tz
            std.debug.print("\nhave tz!", .{});
        }
        const d = cal.unixdaysFromDate([_]u16{ fields.year, fields.month, fields.day });
        return .{
            .year = fields.year,
            .month = fields.month,
            .day = fields.day,
            .hour = fields.hour,
            .minute = fields.minute,
            .second = fields.second,
            .nanosecond = fields.nanosecond,
            .__unix = ( //
                @as(i48, d) * s_per_day +
                @as(u17, fields.hour) * s_per_hour +
                @as(u12, fields.minute) * s_per_minute +
                fields.second //
            ),
        };
    }

    pub fn from_unix(n: i72, unit: Timeunit) RangeError!Datetime {
        if (n > UNIX_s_MAX * @intFromEnum(unit) or n < UNIX_s_MIN * @intFromEnum(unit)) {
            return RangeError.UnixOutOfRange;
        }
        var _dt = Datetime{};
        switch (unit) {
            .second => {
                _dt.__unix = @intCast(n);
                _dt.__normalize();
                return _dt;
            },
            .nanosecond => {
                _dt.__unix = @intCast(@divFloor(n, @as(i72, ns_per_s)));
                _dt.__normalize();
                _dt.nanosecond = @intCast(@mod(n, @as(i72, ns_per_s)));
                return _dt;
            },
        }
    }

    /// Update datetime fields so that they agree with the __internal representation.
    pub fn __normalize(self: *Datetime) void {
        if (self.tzinfo != null) {
            // TODO:  handle tz
            std.debug.print("\nhave tz!", .{});
        }
        const seconds: i39 = @intCast(self.__unix);
        const mdns: i32 = @intCast(@mod(seconds, s_per_day));
        const days: i32 = @intCast(@divFloor(seconds, s_per_day));
        const ymd: [3]u16 = cal.dateFromUnixdays(days);
        self.year = @intCast(ymd[0]);
        self.month = @intCast(ymd[1]);
        self.day = @intCast(ymd[2]);
        self.hour = @intCast(@divFloor(mdns, s_per_hour));
        self.minute = @intCast(@divFloor(@mod(mdns, s_per_hour), s_per_minute));
        self.second = @intCast(@mod(mdns, s_per_minute));
    }

    /// Default string repr is RFC3339 or RFC3339nano if nanoseconds are not zero
    pub fn format(
        self: Datetime,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{ self.year, self.month, self.day, self.hour, self.minute, self.second });
        if (self.nanosecond != 0) try writer.print(".{d:0>9}", .{self.nanosecond});
    }
};
