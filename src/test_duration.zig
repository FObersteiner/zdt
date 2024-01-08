//! test duration from a users's perspective (no internal functionality)
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;

const Datetime = @import("./Datetime.zig");
const Duration = @import("./Duration.zig");

test "from timespan" {
    var td = Duration.fromTimespan(5, Duration.Timespan.nanosecond);
    try testing.expectEqual(@as(i128, 5), td.asNanoseconds());

    td = Duration.fromTimespan(32, Duration.Timespan.second);
    try testing.expectEqual(@as(i128, 32E9), td.asNanoseconds());
    try testing.expectEqual(@as(i64, 32), td.asSeconds());

    td = Duration.fromTimespan(1, Duration.Timespan.week);
    try testing.expectEqual(@as(i64, 7 * 24 * 60 * 60), td.asSeconds());
}

test "add durations" {
    var a = Duration{ .__sec = 1 };
    var b = Duration{ .__sec = 1 };
    var c = a.add(b);
    try testing.expectEqual(@as(i64, 2), c.__sec);
    try testing.expectEqual(@as(u30, 0), c.__nsec);

    a = Duration{ .__sec = 1 };
    b = Duration{ .__nsec = 1 };
    c = a.add(b);
    try testing.expectEqual(@as(i64, 1), c.__sec);
    try testing.expectEqual(@as(u30, 1), c.__nsec);

    a = Duration{ .__nsec = 500_000_000 };
    b = Duration{ .__nsec = 500_000_314 };
    c = a.add(b);
    try testing.expectEqual(@as(i64, 1), c.__sec);
    try testing.expectEqual(@as(u30, 314), c.__nsec);
}

test "sub durations" {
    var a = Duration{ .__sec = 1 };
    var b = Duration{ .__sec = 1 };
    var c = a.sub(b);
    try testing.expectEqual(@as(i64, 0), c.__sec);
    try testing.expectEqual(@as(u30, 0), c.__nsec);

    a = Duration{ .__sec = 1 };
    b = Duration{ .__nsec = 1 };
    c = a.sub(b);
    try testing.expectEqual(@as(i64, 0), c.__sec);
    try testing.expectEqual(@as(u30, 999_999_999), c.__nsec);

    a = Duration{ .__nsec = 500_000_000 };
    b = Duration{ .__nsec = 500_000_314 };
    c = a.sub(b);
    try testing.expectEqual(@as(i64, -1), c.__sec);
    try testing.expectEqual(@as(u30, 999999686), c.__nsec);
}

test "add duration to datetime" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .second = 42 });
    dt = try dt.add(Duration{ .__sec = 1, .__nsec = 0 });
    try testing.expectEqual(@as(i40, 43), dt.__unix);

    dt = try dt.add(Duration{ .__sec = -1, .__nsec = 0 });
    try testing.expectEqual(@as(i40, 42), dt.__unix);

    dt = try dt.add(Duration{ .__sec = -1, .__nsec = 1E9 });
    try testing.expectEqual(@as(i40, 42), dt.__unix);
    try testing.expectEqual(@as(u30, 0), dt.nanosecond);

    dt = try dt.add(Duration.fromTimespan(1, Duration.Timespan.week));
    try testing.expectEqual(@as(u6, 8), dt.day);
}

test "subtract duration from datetime" {
    var dt = try Datetime.fromFields(.{ .year = 1970, .second = 42 });
    dt = try dt.sub(Duration{ .__sec = -1, .__nsec = 0 });
    try testing.expectEqual(@as(i40, 43), dt.__unix);

    dt = try dt.sub(Duration{ .__sec = 1, .__nsec = 0 });
    try testing.expectEqual(@as(i40, 42), dt.__unix);

    dt = try dt.sub(Duration{ .__sec = 1, .__nsec = 1E9 });
    try testing.expectEqual(@as(i40, 42), dt.__unix);
    try testing.expectEqual(@as(u30, 0), dt.nanosecond);
}

test "datetime difference" {
    var a = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    var b = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    var diff = a.diff(b);
    try testing.expectEqual(@as(i64, 0), diff.__sec);
    try testing.expectEqual(@as(u30, 0), diff.__nsec);

    a = try Datetime.fromFields(.{ .year = 1970, .second = 0 });
    b = try Datetime.fromFields(.{ .year = 1970, .second = 1 });
    diff = a.diff(b);
    try testing.expectEqual(@as(i64, -1), diff.__sec);
    try testing.expectEqual(@as(u30, 0), diff.__nsec);

    diff = b.diff(a);
    try testing.expectEqual(@as(i64, 1), diff.__sec);
    try testing.expectEqual(@as(u30, 0), diff.__nsec);
}
