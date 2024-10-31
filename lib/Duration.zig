//! a period in time

const std = @import("std");

const Duration = @This();

// max. digits per quantity in an ISO8601 duration string
const maxDigits: usize = 99;

/// Any duration represented in seconds.
/// Do not modify directly.
__sec: i64 = 0,

/// Fractional seconds in nanoseconds, always positive.
/// Do not modify directly.
__nsec: u32 = 0, // fraction is always positive

/// Create a duration from multiple of specific a timespan
pub fn fromTimespanMultiple(n: i128, timespan: Timespan) Duration {
    const ns: i128 = @as(i128, @intCast(@intFromEnum(timespan))) * n;
    return .{
        .__sec = @intCast(@divFloor(ns, 1_000_000_000)),
        .__nsec = @intCast(@mod(ns, 1_000_000_000)),
    };
}

/// Create a duration from an ISO8601 duration string.
///
/// Since the Duration type represents and absolute difference in time,
/// 'years' and 'months' fields of the duration string must be zero,
/// if not, this is considered an error due to the ambiguity of months and years.
pub fn fromISO8601Duration(string: []const u8) !Duration {
    const fields: RelativeDeltaFields = try parseIsoDur(string);
    if (fields.years != 0 or fields.months != 0) return error.InvalidFormat;
    return .{
        .__sec = @as(i64, fields.days) * 86400 + //
            @as(i64, fields.hours) * 3600 + //
            @as(i64, fields.minutes) * 60 + //
            @as(i64, fields.seconds),
        .__nsec = fields.nanoseconds,
    };
}

/// Convert a Duration to the smallest multiple of the given timespan
/// that can contain the duration
pub fn toTimespanMultiple(duration: Duration, timespan: Timespan) i128 {
    const ns: i128 = duration.asNanoseconds();
    const divisor: u64 = @intFromEnum(timespan);
    const result = std.math.divCeil(i128, ns, @as(i128, divisor)) catch unreachable;
    return @intCast(result);
}

/// Representation with fractional seconds
pub fn totalSeconds(duration: Duration) f64 {
    const ns = duration.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 1_000_000_000);
}

/// Add a duration to another. Makes a new Duration.
pub fn add(this: Duration, other: Duration) Duration {
    const s: i64 = this.__sec + other.__sec;
    const ns: u32 = this.__nsec + other.__nsec;
    return .{
        .__sec = s + @divFloor(ns, 1_000_000_000),
        .__nsec = @truncate(@mod(ns, 1_000_000_000)),
    };
}

/// Subtract a duration from another. Makes a new Duration.
pub fn sub(this: Duration, other: Duration) Duration {
    var s: i64 = this.__sec - other.__sec;
    var ns: i32 = @as(i32, @intCast(this.__nsec)) - @as(i32, @intCast(other.__nsec));
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Convert a duration to seconds, don't forget the nanos.
pub fn asSeconds(duration: Duration) i64 {
    if (duration.__nsec > 500_000_000) return duration.__sec + 1;
    return duration.__sec;
}

/// Convert a duration to nanos.
pub fn asNanoseconds(duration: Duration) i128 {
    return duration.__sec * 1_000_000_000 + duration.__nsec;
}

// Formatted printing for Duration type. Defaults to ISO8601 duration format,
// years/months/days excluded due to the ambiguity of months and years.
pub fn format(
    duration: Duration,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    const is_negative = duration.__sec < 0;
    var s: u64 = if (is_negative) @intCast(duration.__sec * -1) else @intCast(duration.__sec);

    // account for fraction always being positive:
    if (is_negative and duration.__nsec > 0) s -= 1;

    var frac = if (is_negative) 1_000_000_000 - duration.__nsec else duration.__nsec;
    // truncate zeros from fractional part
    if (frac > 0) {
        while (frac % 10 == 0) : (frac /= 10) {}
    }

    const hours = @divFloor(s, 3600);
    const remainder = @rem(s, 3600);
    const minutes = @divFloor(remainder, 60);
    const seconds = @rem(remainder, 60);

    if (is_negative) try writer.print("-", .{});

    try writer.print("PT{d}H{d}M{d}", .{ hours, minutes, seconds });

    if (duration.__nsec > 0) {
        try writer.print(".{d}S", .{frac});
    } else {
        try writer.print("S", .{});
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

// pub fn fromString(string: []const u8, directives: []const u8) !Duration {
//
// };

// pub fn fromISO8601(string: []const u8) !Duration {
//
// };

// pub fn toString(duration: Duration, directives: []const u8, writer: anytype) !void {
//
// };

// pub fn toISO8601(duration: Duration, writer: anytype) void {
//
// };

/// Fields of a duration that is relative to a datetime.
pub const RelativeDeltaFields = struct {
    years: i32 = 0,
    months: i32 = 0,
    days: i32 = 0,
    hours: i32 = 0,
    minutes: i32 = 0,
    seconds: i32 = 0,
    nanoseconds: u32 = 0,

    // /// TODO : to Duration (absoulte) - truncate months and years
    // pub fn toDurationTruncate(fields: RelativeDeltaFields) Duration {
    //
    // }
    //
    // /// TODO : to Duration (absoulte) - return error if years or months are != 0
    // pub fn toDuration(fields: RelativeDeltaFields) !Duration {
    //
    // }
};

/// convert ISO8601 duration from string to RelativeDeltaFields.
pub fn parseIsoDur(string: []const u8) !RelativeDeltaFields {
    var result: RelativeDeltaFields = .{};

    // at least 3 characters, e.g. P0D
    if (string.len < 3) return error.InvalidFormat;

    // must end with a character
    if (!std.ascii.isAlphabetic(string[string.len - 1])) return error.InvalidFormat;

    var stop: usize = 0;
    var invert: bool = false;

    if (string[stop] == '-') {
        invert = true;
        stop += 1;
    }

    //log.info("invert: {any}", .{invert});

    // must start with P (ignore sign)
    if (string[stop] != 'P') return error.InvalidFormat;
    stop += 1;

    if (string[stop] == 'T') stop += 1;

    var idx: usize = string.len - 1;

    // need flags to keep track of what has been parsed already,
    // and in which order:
    // quantity:   Y m d T H M S
    // bit/order:  - - 4 3 2 1 0
    var flags: u8 = 0;

    while (idx > stop) {
        //log.info("flags: {b}", .{flags});
        switch (string[idx]) {
            'S' => {
                // seconds come last, so no other quantity must have been parsed yet
                if (flags > 0) return error.InvalidFormat;
                // log.info("parse seconds!", .{});
                idx -= 1;
                flags |= 0b1;
                _ = try parseAndAdvanceS(string, &idx, &result.seconds, &result.nanoseconds);
                if (invert) result.seconds *= -1;
                // log.info("seconds: {d}", .{quantity});
            },
            'M' => {
                // 'M' may appear twice; its either minutes or months;
                // depending on if the 'T' has been seen =>
                // minutes if (flags & 0b1000 == 0), otherwise months
                if (flags & 0b1000 == 0) {
                    // minutes come second to last, so only seconds may have been parsed yet
                    // log.info("parse minutes!", .{});
                    if (flags > 1) return error.InvalidFormat;
                    idx -= 1;
                    flags |= 0b10;
                    var quantity = try parseAndAdvanceYMDHM(i32, string, &idx);
                    if (invert) quantity *= -1;
                    result.minutes = quantity;
                    // log.info("minutes: {d}", .{quantity});
                } else {
                    // log.info("parse months!", .{});
                    if (flags > 0b11111) return error.InvalidFormat;
                    idx -= 1;
                    flags |= 0b100000;
                    var quantity = try parseAndAdvanceYMDHM(i32, string, &idx);
                    if (invert) quantity *= -1;
                    result.months = quantity;
                    // log.info("months: {d}", .{quantity});
                }
            },
            'H' => { // hours are the third-to-last component,
                // so only seconds and minutes may have been parsed yet
                if (flags > 0b11) return error.InvalidFormat;
                // log.info("parse hours!", .{});
                idx -= 1;
                flags |= 0b100;
                var quantity = try parseAndAdvanceYMDHM(i32, string, &idx);
                if (invert) quantity *= -1;
                result.hours = quantity;
                // log.info("hours: {d}", .{quantity});
            },
            'T' => { // date/time separator must only appear once
                if (flags > 0b111) return error.InvalidFormat;
                // log.info("date/time sep!", .{});
                idx -= 1;
                flags |= 0b1000;
            },
            'D' => {
                if (flags > 0b1111) return error.InvalidFormat;
                // log.info("parse days!", .{});
                idx -= 1;
                flags |= 0b10000;
                var quantity = try parseAndAdvanceYMDHM(i32, string, &idx);
                if (invert) quantity *= -1;
                result.days = quantity;
                // log.info("days: {d}", .{quantity});
            },
            'Y' => {
                if (flags > 0b111111) return error.InvalidFormat;
                // log.info("parse years!", .{});
                idx -= 1;
                flags |= 0b1000000;
                var quantity = try parseAndAdvanceYMDHM(i32, string, &idx);
                if (invert) quantity *= -1;
                result.years = quantity;
                // log.info("years: {d}", .{quantity});
            },
            else => return error.InvalidFormat,
        }
    }
    //    log.info("done. idx: {d}", .{idx});
    return result;
}

/// Backwards-looking parse chars from 'string' seconds and nanoseconds (sum),
/// end index is the value of 'idx_ptr' when the function is called.
/// start index is determined automatically.
///
/// This is a procedure; it modifies input pointer 'sec' and 'nsec' values in-place.
/// This way, we can work around the fact that there are no multiple-return functions
/// and save arithmetic operations (compared to using a single return value).
fn parseAndAdvanceS(string: []const u8, idx_ptr: *usize, sec: *i32, nsec: *u32) !void {
    const end_idx = idx_ptr.*;
    var have_fraction: bool = false;
    while (idx_ptr.* > 0 and
        end_idx - idx_ptr.* < maxDigits and
        !std.ascii.isAlphabetic(string[idx_ptr.*])) : (idx_ptr.* -= 1)
    {
        if (string[idx_ptr.*] == '.') have_fraction = true;
    }

    // short cut: there is no fraction
    if (!have_fraction) {
        sec.* = try std.fmt.parseInt(i32, string[idx_ptr.* + 1 .. end_idx + 1], 10);
        return;
    }

    // fractional seconds are specified. need to convert them to nanoseconds,
    // and truncate anything behind the nineth digit.
    const substr = string[idx_ptr.* + 1 .. end_idx + 1];
    const idx_dot = std.mem.indexOfScalar(u8, substr, '.');
    if (idx_dot == null) return error.InvalidFormat;

    sec.* = try std.fmt.parseInt(i32, substr[0..idx_dot.?], 10);

    var substr_nanos = substr[idx_dot.? + 1 ..];
    if (substr_nanos.len > 9) substr_nanos = substr_nanos[0..9];
    const nanos = try std.fmt.parseInt(u32, substr_nanos, 10);

    // nanos might actually be another unit; if there is e.g. 3 digits of fractional
    // seconds, we have milliseconds (1/10^3 s) and need to multiply by 10^(9-3) to get ns.
    const missing = 9 - substr_nanos.len;
    const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
    nsec.* = nanos * f;
}

/// backwards-looking parse chars from 'string' to int (base 10),
/// end index is the value of 'idx_ptr' when the function is called.
/// start index is determined automatically.
fn parseAndAdvanceYMDHM(comptime T: type, string: []const u8, idx_ptr: *usize) !T {
    const end_idx = idx_ptr.*;
    while (idx_ptr.* > 0 and
        end_idx - idx_ptr.* < maxDigits and
        !std.ascii.isAlphabetic(string[idx_ptr.*])) : (idx_ptr.* -= 1)
    {}
    return try std.fmt.parseInt(T, string[idx_ptr.* + 1 .. end_idx + 1], 10);
}
