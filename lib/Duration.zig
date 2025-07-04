//! a period in time

const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.zdt__Duration);

const FormatError = @import("./errors.zig").FormatError;
const RangeError = @import("./errors.zig").RangeError;

const Duration = @This();

// max. digits per quantity in an ISO8601 duration string (arbitrary)
const max_n_digits: usize = 99;

/// For the 'asNanoseconds' method to work correctly, the maximum number of seconds
/// that can be represented by a Duration's __sec is (max(i128) - (1e9 - 1)) / 1e9.
/// The minus 1e9 are required to correctly handle __nsec, which can be (1e9 - 1) max.
pub const max_sec: i128 = 170141183460469231731687303714; // ~36909691 years

/// For the minimum, it is just min(i128) / 1e9 since the __nsec is always positive.
pub const min_sec: i128 = -170141183460469231731687303715;

/// Any duration represented in seconds.
/// Do not modify directly.
__sec: i128 = 0,

/// Fractional seconds in nanoseconds, always >= 0.
/// Do not modify directly.
__nsec: u32 = 0,

/// Create a duration from multiple of specific a timespan.
///
/// The Duration type can represent any timespan that can fit into  a 64 bit
/// signed integer, i.e. up to 2^63 weeks. Therefore, no error is returned.
pub fn fromTimespanMultiple(n: i64, timespan: Timespan) Duration {
    const ns: i128 = @as(i128, @intCast(@intFromEnum(timespan))) * n;
    return .{
        .__sec = @intCast(@divFloor(ns, 1_000_000_000)),
        .__nsec = @intCast(@mod(ns, 1_000_000_000)),
    };
}

/// Create a duration from an 'ISO8601 duration' style string, e.g.
///
/// ```
/// "PT9H" : 9 hours
/// "PT1.234S" : 1 second, 234 milliseconds
/// ```
///
/// Restrictions:
/// - Since the Duration type represents an absolute difference in time,
///   'years' and 'months' fields of the string ('Y', 'M') must be zero.
/// - A fractional value is only allowed for seconds ('S').
/// - The string might be prefixed '-' to indicate a negative duration.
///   Individual signed components are not allowed.
pub fn fromISO8601(string: []const u8) FormatError!Duration {
    const fields: RelativeDelta = try RelativeDelta.fromISO8601(string);
    return try RelativeDelta.toDuration(fields);
}

/// Convert a Duration to the smallest multiple of the given timespan
/// that can contain the duration
pub fn toTimespanMultiple(duration: Duration, timespan: Timespan) i128 {
    const ns: i128 = duration.asNanoseconds();
    const divisor: u64 = @intFromEnum(timespan);
    return std.math.divCeil(i128, ns, @as(i128, divisor)) catch unreachable;
}

/// Representation as seconds with fractional seconds
pub fn totalSeconds(duration: Duration) f64 {
    const ns = duration.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 1_000_000_000);
}

/// Representation as minutes with fractional minutes
pub fn totalMinutes(duration: Duration) f64 {
    const ns = duration.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 60_000_000_000);
}

/// Representation as hours with fractional hours
pub fn totalHours(duration: Duration) f64 {
    const ns = duration.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 3_600_000_000_000);
}

/// Representation as days with fractional days
pub fn totalDays(duration: Duration) f64 {
    const ns = duration.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 86_400_000_000_000);
}

/// Add a duration to another. Makes a new Duration.
///
/// Returns RangeError.SecondsOutOfRange if the sum of the durations
/// wouldn't satisfy the requirement of 'asNanoseconds()' to work.
pub fn add(this: Duration, other: Duration) RangeError!Duration {
    const s: i128 = this.__sec + other.__sec;
    const ns: u32 = this.__nsec + other.__nsec;
    const result = Duration{
        .__sec = s + @divFloor(ns, 1_000_000_000),
        .__nsec = @truncate(@mod(ns, 1_000_000_000)),
    };
    if (result.__sec > max_sec or result.__sec < min_sec) return RangeError.SecondOutOfRange;
    return result;
}

/// Add a duration to another. Makes a new Duration.
///
/// If the resulting Duration would be out-of-range to satisfy the
/// requirement of 'asNanoseconds()' to work, the result is clipped
/// to max_sec or min_sec, respectively.
pub fn addClip(this: Duration, other: Duration) Duration {
    const s: i128 = this.__sec + other.__sec;
    const ns: u32 = this.__nsec + other.__nsec;
    var result = Duration{
        .__sec = s + @divFloor(ns, 1_000_000_000),
        .__nsec = @truncate(@mod(ns, 1_000_000_000)),
    };
    if (result.__sec > max_sec) {
        result.__sec = max_sec;
        return result;
    }
    if (result.__sec < min_sec) {
        result.__sec = min_sec;
        return result;
    }
    return result;
}

/// Subtract a duration from another. Makes a new Duration.
///
/// Returns RangeError.SecondsOutOfRange if the difference of the durations
/// wouldn't satisfy the requirement of 'asNanoseconds()' to work.
pub fn sub(this: Duration, other: Duration) RangeError!Duration {
    var s: i128 = this.__sec - other.__sec;
    var ns: i32 = @as(i32, @intCast(this.__nsec)) - @as(i32, @intCast(other.__nsec));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    const result = Duration{ .__sec = s, .__nsec = @intCast(ns) };
    if (result.__sec > max_sec or result.__sec < min_sec) return RangeError.SecondOutOfRange;
    return result;
}

/// Subtract a duration from another. Makes a new Duration.
///
/// If the resulting Duration would be out-of-range to satisfy the
/// requirement of 'asNanoseconds()' to work, the result is clipped
/// to max_sec or min_sec, respectively.
pub fn subClip(this: Duration, other: Duration) Duration {
    var s: i128 = this.__sec - other.__sec;
    var ns: i32 = @as(i32, @intCast(this.__nsec)) - @as(i32, @intCast(other.__nsec));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    var result = Duration{ .__sec = s, .__nsec = @intCast(ns) };
    if (result.__sec < min_sec) {
        result.__sec = min_sec;
        return result;
    }
    if (result.__sec > max_sec) {
        result.__sec = max_sec;
        return result;
    }
    return result;
}

/// Convert a duration to seconds, don't forget the nanos just because they're small 😎
pub fn asSeconds(duration: Duration) i128 {
    if (duration.__nsec > 500_000_000) return duration.__sec + 1;
    return duration.__sec;
}

/// Convert a duration to nanos.
pub fn asNanoseconds(duration: Duration) i128 {
    return duration.__sec * 1_000_000_000 + duration.__nsec;
}

/// Formatted printing for Duration type. Defaults to 'ISO8601-duration'-like format.
pub fn format(
    duration: Duration,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) anyerror!void {
    _ = options;
    _ = fmt;

    if (duration.__sec == 0 and duration.__nsec == 0) return try writer.print("PT0S", .{});

    const rd = RelativeDelta.fromDuration(&duration);

    const is_negative = duration.__sec < 0;
    if (is_negative) try writer.print("-P", .{}) else try writer.print("P", .{});

    if (rd.weeks > 0) try writer.print("{d}W", .{rd.weeks});
    if (rd.days > 0) try writer.print("{d}D", .{rd.days});

    if (rd.hours > 0 or rd.minutes > 0 or rd.seconds > 0 or rd.nanoseconds > 0)
        try writer.print("T", .{})
    else
        return;

    if (rd.hours > 0) try writer.print("{d}H", .{rd.hours});
    if (rd.minutes > 0) try writer.print("{d}M", .{rd.minutes});

    if (rd.seconds == 0 and rd.nanoseconds == 0) return;

    var frac = duration.__nsec;
    if (frac > 0) { // truncate zeros from fractional part
        while (frac % 10 == 0) : (frac /= 10) {}
    }

    if (frac > 0) {
        try writer.print("{d}.{d}S", .{ rd.seconds, frac });
    } else {
        try writer.print("{d}S", .{rd.seconds});
    }
}

/// Resolution of a duration in terms of fractions of a second. Mainly used
/// to specify input resolution for creating datetime from Unix time.
pub const Resolution = enum(u32) {
    second = 1,
    millisecond = 1_000,
    microsecond = 1_000_000,
    nanosecond = 1_000_000_000,
};

/// Span in time of a duration, in terms of multiples of a nanosecond.
pub const Timespan = enum(u64) {
    nanosecond = 1,
    microsecond = 1_000,
    millisecond = 1_000_000,
    second = 1_000_000_000,
    minute = 1_000_000_000 * 60,
    hour = 1_000_000_000 * 60 * 60,
    day = 1_000_000_000 * 60 * 60 * 24,
    week = 1_000_000_000 * 60 * 60 * 24 * 7,
};

/// Relative difference in time;
/// might contain ambiguous quantities months and years.
pub const RelativeDelta = struct {
    years: u32 = 0,
    months: u32 = 0,
    weeks: u32 = 0,
    days: u32 = 0,
    hours: u32 = 0,
    minutes: u32 = 0,
    seconds: u32 = 0,
    nanoseconds: u32 = 0,
    negative: bool = false,

    /// Normalize time fields to their 'normal' modulo, e.g. hours 0-23 etc.
    /// Fields up to "days" might change; other fields stay untouched.
    pub fn normalize(this: *const RelativeDelta) RelativeDelta {
        var result: RelativeDelta = .{
            .years = this.years,
            .months = this.months,
            .weeks = this.weeks,
            .days = this.days,
            .hours = this.hours,
            .minutes = this.minutes,
            .seconds = this.seconds,
            .nanoseconds = this.nanoseconds,
            .negative = this.negative,
        };

        if (result.seconds > 59) {
            result.minutes += result.seconds / 60;
            result.seconds = result.seconds % 60;
        }
        if (result.minutes > 59) {
            result.hours += result.minutes / 60;
            result.minutes = result.minutes % 60;
        }
        if (result.hours > 24) {
            result.days += result.hours / 24;
            result.hours = result.hours % 24;
        }

        return result;
    }

    /// Make a RelativeDelta from a Duration.
    pub fn fromDuration(duration: *const Duration) RelativeDelta {
        var result: RelativeDelta = .{
            .years = 0,
            .months = 0,
            .nanoseconds = duration.__nsec,
            .negative = if (duration.__sec < 0) true else false,
        };

        var secs: u128 = @abs(duration.__sec);
        result.weeks = @truncate(secs / (86400 * 7));
        secs -|= @as(u64, result.weeks) * (86400 * 7);

        result.days = @truncate(secs / 86400);
        secs -|= @as(u64, result.days) * 86400;

        result.hours = @truncate(secs / 3600);
        secs -|= @as(u64, result.hours) * 3600;

        result.minutes = @truncate(secs / 60);
        secs -|= @as(u64, result.minutes) * 60;

        result.seconds = @truncate(secs);

        return result;
    }

    /// Make a Duration from a RelativeDelta.
    pub fn toDuration(reldelta: RelativeDelta) FormatError!Duration {
        if (reldelta.years != 0 or reldelta.months != 0) return FormatError.InvalidFormat;
        const total_secs: i64 = @as(i64, reldelta.weeks) * 7 * 86400 + //
            @as(i64, reldelta.days) * 86400 + //
            @as(i64, reldelta.hours) * 3600 + //
            @as(i64, reldelta.minutes) * 60 + //
            @as(i64, reldelta.seconds);
        return .{
            .__sec = if (reldelta.negative) total_secs * -1 else total_secs,
            .__nsec = reldelta.nanoseconds,
        };
    }

    /// Convert ISO8601 duration from string to a RelativeDelta.
    ///
    /// Restrictions:
    /// - A fractional value is only allowed for seconds ('S').
    /// - The string might be prefixed '-' to indicate a negative duration.
    ///   Individual signed components are not allowed.
    pub fn fromISO8601(string: []const u8) FormatError!RelativeDelta {
        var result: RelativeDelta = .{};

        // at least 3 characters, e.g. P0D
        if (string.len < 3) return FormatError.InvalidFormat;

        // must end with a character
        if (!std.ascii.isAlphabetic(string[string.len - 1])) return FormatError.InvalidFormat;

        var stop: usize = 0;

        if (string[stop] == '-') { // minus prefix
            result.negative = true;
            stop += 1;
        }

        // must start with P (ignore sign)
        if (string[stop] != 'P') return FormatError.InvalidFormat;
        stop += 1;

        // 'P' must be followed by either 'T', '-' or a digit;
        // if 'P' is followed by a 'T', that must also be followed by a '-' or a digit
        if (string[stop] == 'T') {
            if (!(std.ascii.isDigit(string[stop + 1]) or string[stop + 1] == '-'))
                return FormatError.InvalidFormat;
        } else {
            if (!(std.ascii.isDigit(string[stop]) or string[stop] == '-'))
                return FormatError.InvalidFormat;
        }

        var idx: usize = string.len - 1;

        // need flags to keep track of what has been parsed already,
        // and in which order.
        //
        // quantity/token:  Y m W d T H M S
        // bit/order:       7 6 5 4 3 2 1 0
        var flags: u8 = 0;

        while (idx >= stop) {
            switch (string[idx]) {
                'S' => {
                    // seconds come last, so no other quantity must have been parsed yet
                    if (flags > 0) return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1;
                    _ = try parseAndAdvanceS(string, &idx, &result.seconds, &result.nanoseconds);
                },
                'M' => {
                    // 'M' may appear twice; it's either minutes or months;
                    // depending on if the 'T' has been seen =>
                    // minutes if (flags & 0b1000 == 0), otherwise months
                    if (flags & 0b1000 == 0) {
                        // minutes come second to last, so only seconds may have been parsed yet
                        if (flags > 1) return FormatError.InvalidFormat;
                        idx -= 1;
                        flags |= 1 << 1;
                        const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                        result.minutes = quantity;
                    } else {
                        if (flags > 0b111111) return FormatError.InvalidFormat;
                        // if no 'T' was parsed before, flags 0, 1 and 2 must be 0:
                        if (flags & 0b1000 == 0 and flags & 0b111 != 0)
                            return FormatError.InvalidFormat;
                        idx -= 1;
                        flags |= 1 << 6;
                        const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                        result.months = quantity;
                    }
                },
                'H' => { // hours are the third-to-last component,
                    // so only seconds and minutes may have been parsed yet
                    if (flags > 0b11) return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1 << 2;
                    const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                    result.hours = quantity;
                },
                'T' => { // date/time separator must only appear once
                    if (flags > 0b111) return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1 << 3; // 0b1000;
                },
                'D' => {
                    if (flags > 0b1111) return FormatError.InvalidFormat;
                    if (flags & 0b1000 == 0 and flags & 0b111 != 0)
                        return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1 << 4;
                    const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                    result.days = quantity;
                },
                'W' => {
                    if (flags > 0b11111) return FormatError.InvalidFormat;
                    if (flags & 0b1000 == 0 and flags & 0b111 != 0)
                        return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1 << 5;
                    const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                    result.weeks = quantity;
                },
                'Y' => {
                    if (flags & 1 << 7 != 0) return FormatError.InvalidFormat;
                    if (flags & 0b1000 == 0 and flags & 0b111 != 0)
                        return FormatError.InvalidFormat;
                    idx -= 1;
                    flags |= 1 << 7;
                    const quantity = try parseAndAdvanceYmWdHM(u32, string, &idx);
                    result.years = quantity;
                },
                else => return FormatError.InvalidFormat,
            }
        }

        return result;
    }
};

/// Backwards-looking parse chars from 'string' seconds and nanoseconds (sum),
/// end index is the value of 'idx_ptr' when the function is called.
/// Start index is determined automatically.
///
/// This is a procedure; it modifies input pointer 'sec' and 'nsec' values in-place.
/// This way, we can work around the fact that there are no multiple-return functions
/// and save arithmetic operations (compared to using a single return value).
fn parseAndAdvanceS(string: []const u8, idx_ptr: *usize, sec: *u32, nsec: *u32) FormatError!void {
    const end_idx = idx_ptr.*;
    var have_fraction: bool = false;
    while (idx_ptr.* > 0 and
        end_idx - idx_ptr.* < max_n_digits and
        !std.ascii.isAlphabetic(string[idx_ptr.*])) : (idx_ptr.* -= 1)
    {
        if (string[idx_ptr.*] == '.') have_fraction = true;
    }

    if (have_fraction) {
        // fractional seconds are specified. need to convert them to nanoseconds,
        // and truncate anything behind the nineth digit.
        const substr = string[idx_ptr.* + 1 .. end_idx + 1];
        const idx_dot = std.mem.indexOfScalar(u8, substr, '.');
        if (idx_dot == null) return FormatError.InvalidFormat;

        sec.* = try std.fmt.parseInt(u32, substr[0..idx_dot.?], 10);

        var substr_nanos = substr[idx_dot.? + 1 ..];
        if (substr_nanos.len > 9) substr_nanos = substr_nanos[0..9];
        const nanos = try std.fmt.parseInt(u32, substr_nanos, 10);

        // nanos might actually be another unit; if there are e.g. 3 digits of fractional
        // seconds, we have milliseconds (1/10^3 s) and need to multiply by 10^(9-3) to get ns.
        const missing = 9 - substr_nanos.len;
        const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
        nsec.* = nanos * f;
    } else { // short cut: there is no fraction
        sec.* = try std.fmt.parseInt(u32, string[idx_ptr.* + 1 .. end_idx + 1], 10);
        return;
    }
}

/// Backwards-looking parse chars from 'string' to int (base 10),
/// end index is the value of 'idx_ptr' when the function is called.
/// start index is determined automatically.
fn parseAndAdvanceYmWdHM(comptime T: type, string: []const u8, idx_ptr: *usize) FormatError!T {
    const end_idx = idx_ptr.*;
    while (idx_ptr.* > 0 and
        end_idx - idx_ptr.* < max_n_digits and
        !std.ascii.isAlphabetic(string[idx_ptr.*])) : (idx_ptr.* -= 1)
    {}
    return try std.fmt.parseInt(T, string[idx_ptr.* + 1 .. end_idx + 1], 10);
}
