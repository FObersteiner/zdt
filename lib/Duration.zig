//! a period in time

const std = @import("std");

const Duration = @This();

__sec: i64 = 0,
__nsec: u30 = 0, // fraction is always positive

/// Create a duration from multiple of specific a timespan
pub fn fromTimespanMultiple(n: i72, timespan: Timespan) Duration {
    const ns: i72 = @as(i72, @intCast(@intFromEnum(timespan))) * n;
    return .{
        .__sec = @intCast(@divFloor(ns, 1_000_000_000)),
        .__nsec = @intCast(@mod(ns, 1_000_000_000)),
    };
}

/// Convert a Duration to the smallest multiple of the given timespan
/// that can contain the duration
pub fn toTimespanMultiple(self: Duration, timespan: Timespan) i72 {
    const ns: i128 = self.asNanoseconds();
    const divisor: u56 = @intFromEnum(timespan);
    const result = std.math.divCeil(i128, ns, @as(i128, divisor)) catch 0;
    return @intCast(result);
}

/// Representation with fractional seconds
pub fn totalSeconds(self: Duration) f64 {
    const ns = self.asNanoseconds();
    return @floatCast(@as(f128, @floatFromInt(ns)) / 1_000_000_000);
}

/// Add a duration to another. Makes a new Duration.
pub fn add(this: Duration, other: Duration) Duration {
    const s: i64 = this.__sec + other.__sec;
    const ns: u31 = this.__nsec + other.__nsec;
    return .{
        .__sec = s + @divFloor(ns, 1_000_000_000),
        .__nsec = @truncate(@mod(ns, 1_000_000_000)),
    };
}

/// Subtract a duration from another. Makes a new Duration.
pub fn sub(this: Duration, other: Duration) Duration {
    var s: i64 = this.__sec - other.__sec;
    var ns: i32 = @as(i32, this.__nsec) - other.__nsec;
    if (ns < 0) {
        s -= 1;
        ns += 1_000_000_000;
    }
    return .{ .__sec = s, .__nsec = @intCast(ns) };
}

/// Convert a duration to seconds, don't forget the nanos.
pub fn asSeconds(self: Duration) i64 {
    if (self.__nsec > 500_000_000) return self.__sec + 1;
    return self.__sec;
}

/// Convert a duration to nanos.
pub fn asNanoseconds(self: Duration) i128 {
    return self.__sec * 1_000_000_000 + self.__nsec;
}

// Formatted printing for Duration type. Defaults to ISO8601 duration format.
pub fn format(
    self: Duration,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    const is_negative = self.__sec < 0;
    var s: u64 = if (is_negative) @intCast(self.__sec * -1) else @intCast(self.__sec);

    // account for fraction always being positive:
    if (is_negative and self.__nsec > 0) s -= 1;
    const ns = if (is_negative) 1_000_000_000 - self.__nsec else self.__nsec;

    const hours = @divFloor(s, 3600);
    const remainder = @rem(s, 3600);
    const minutes = @divFloor(remainder, 60);
    const seconds = @rem(remainder, 60);

    if (is_negative) try writer.print("-", .{});
    try writer.print("PT{d:0>2}H{d:0>2}M{d:0>2}", .{ hours, minutes, seconds });

    if (self.__nsec > 0) {
        try writer.print(".{d:0>9}S", .{ns});
    } else {
        try writer.print("S", .{});
    }
}

/// Resolution of a duration in terms of fractions of a second. Mainly used
/// to specify input resolution for creating datetime from Unix time.
pub const Resolution = enum(u30) {
    second = 1,
    millisecond = 1_000,
    microsecond = 1_000_000,
    nanosecond = 1_000_000_000,
};

/// Span in time of a duration, in terms of multiples of a nanosecond.
pub const Timespan = enum(u56) {
    nanosecond = 1,
    microsecond = 1_000,
    millisecond = 1_000_000,
    second = 1_000_000_000,
    minute = 1_000_000_000 * 60,
    hour = 1_000_000_000 * 60 * 60,
    day = 1_000_000_000 * 60 * 60 * 24,
    week = 1_000_000_000 * 60 * 60 * 24 * 7,
};
