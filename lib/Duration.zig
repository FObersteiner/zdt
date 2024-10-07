//! a period in time

const std = @import("std");

const Duration = @This();

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

// Formatted printing for Duration type. Defaults to ISO8601 duration format.
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
    const ns = if (is_negative) 1_000_000_000 - duration.__nsec else duration.__nsec;

    const hours = @divFloor(s, 3600);
    const remainder = @rem(s, 3600);
    const minutes = @divFloor(remainder, 60);
    const seconds = @rem(remainder, 60);

    if (is_negative) try writer.print("-", .{});
    try writer.print("PT{d:0>2}H{d:0>2}M{d:0>2}", .{ hours, minutes, seconds });

    if (duration.__nsec > 0) {
        try writer.print(".{d:0>9}S", .{ns});
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
