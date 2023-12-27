const std = @import("std");
const datetime = @import("datetime.zig");
const str = @import("stringIO.zig");
const tz = @import("timezone.zig");

const TestCase = struct {
    string: []const u8,
    dt: datetime.Datetime,
    directive: []const u8 = "",
};

test "parse format string" {
    const parts = try str.parseFormatAlloc(std.testing.allocator, "%Y-%m-%d %H:%M:%S.%f");
    defer std.testing.allocator.free(parts);
    try std.testing.expectEqualSlices(str.Part, &[_]str.Part{
        .{ .specifier = .year },
        .{ .literal = '-' },
        .{ .specifier = .month },
        .{ .literal = '-' },
        .{ .specifier = .day },
        .{ .literal = ' ' },
        .{ .specifier = .hour },
        .{ .literal = ':' },
        .{ .specifier = .min },
        .{ .literal = ':' },
        .{ .specifier = .sec },
        .{ .literal = '.' },
        .{ .specifier = .nanos },
    }, parts);
}

// ---- Datetime to String ----

test "format naive datetimes with parts api" {
    const cases = [_]TestCase{
        .{ .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }), .string = "2021-02-18 17:00:00" },
        .{ .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }), .string = "1970-01-01 00:00:00" },
    };

    const parts = try str.parseFormatAlloc(std.testing.allocator, "%Y-%m-%d %H:%M:%S");
    defer std.testing.allocator.free(parts);

    for (cases) |case| {
        var s = std.ArrayList(u8).init(std.testing.allocator);
        defer s.deinit();
        try str.formatDatetimeParts(s.writer(), parts, case.dt);
        try std.testing.expectEqualStrings(case.string, s.items);
    }
}

test "format naive datetimes with format string api" {
    const cases = [_]TestCase{
        .{ .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }), .string = "2021-02-18 17:00:00" },
        .{ .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }), .string = "1970-01-01 00:00:00" },
    };

    for (cases) |case| {
        var s = std.ArrayList(u8).init(std.testing.allocator);
        defer s.deinit();
        try str.formatDatetime(s.writer(), "%Y-%m-%d %H:%M:%S", case.dt);
        try std.testing.expectEqualStrings(case.string, s.items);
    }
}

test "format datetime with literal characters in format string" {
    const cases = [_]TestCase{ .{
        .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }),
        .string = "2021-02-18T17:00:00",
        .directive = "%Y-%m-%dT%H:%M:%S",
    }, .{
        .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }),
        .string = "Unix epoch 1970-01-01 00:00:00",
        .directive = "Unix epoch %Y-%m-%d %H:%M:%S",
    }, .{
        .dt = try datetime.Datetime.naiveFromList(.{ 2023, 12, 9, 1, 2, 3, 0 }),
        .string = "% 2023-12-09 % 01:02:03 %",
        .directive = "%% %Y-%m-%d %% %H:%M:%S %%",
    }, .{
        .dt = try datetime.Datetime.naiveFromList(.{ 2023, 12, 10, 1, 2, 3, 456789 }),
        .string = "2023-12-10 01:02:03.000456789",
        .directive = "%Y-%m-%d %H:%M:%S.%f",
    } };

    for (cases) |case| {
        var s = std.ArrayList(u8).init(std.testing.allocator);
        defer s.deinit();
        try str.formatDatetime(s.writer(), case.directive, case.dt);
        try std.testing.expectEqualStrings(case.string, s.items);
    }
}

test "format with z" {
    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(3600, "");
    const dt = try datetime.Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const string = "2021-02-18T17:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatDatetime(s.writer(), directive, dt);
    try std.testing.expectEqualStrings(string, s.items);
}

test "format with z, full day off" {
    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(-86400, "");
    const dt = try datetime.Datetime.fromFields(.{ .year = 1970, .month = 2, .day = 13, .hour = 12, .tzinfo = tzinfo });
    const string = "1970-02-13T12:00:00-24:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatDatetime(s.writer(), directive, dt);
    try std.testing.expectEqualStrings(string, s.items);
}

test "format with z, strange directive" {
    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(900, "");
    const dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 12, .day = 9, .hour = 1, .minute = 2, .second = 3, .tzinfo = tzinfo });
    const string = "% 2023-12-09 % 01:02:03 % +00:15";
    const directive = "%% %Y-%m-%d %% %H:%M:%S %% %z";
    try str.formatDatetime(s.writer(), directive, dt);
    try std.testing.expectEqualStrings(string, s.items);
}

// ---- String to Datetime ----

test "comptime parse with comptime format string" {
    const cases = [_]TestCase{
        .{ .string = "2021-02-18 17:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }) },
        .{ .string = "1970-01-01 00:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };

    for (cases) |case| {
        const dt = try str.parseDatetime("%Y-%m-%d %H:%M:%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
    }
}

test "parse single digits" {
    const cases = [_]TestCase{
        // single digit y m d
        .{ .string = "1-1-1 00:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 1, 1, 1, 0, 0, 0, 0 }) },
        // single digit field at end of string
        .{ .string = "1-1-1 0:0:0", .dt = try datetime.Datetime.naiveFromList(.{ 1, 1, 1, 0, 0, 0, 0 }) },
    };

    for (cases) |case| {
        const dt = try str.parseDatetime("%Y-%m-%d %H:%M:%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
    }
}

test "parsing directives do not match fields in string" {
    var err = str.parseDatetime("%Y-%m-%d %H%%%M%%%S", "1970-01-01 00:00:00");
    try std.testing.expectError(error.InvalidFormat, err);

    err = str.parseDatetime("%Y-%m-%dT%H:%M:%S", "1970-01-01 00:00:00");
    try std.testing.expectError(error.InvalidFormat, err);

    err = str.parseDatetime("%", "1970-01-01 00:00:00");
    try std.testing.expectError(error.InvalidFormat, err);

    err = str.parseDatetime("%Y-%m-%d %H:%M:%S %z", "1970-01-01 00:00:00 +7");
    try std.testing.expectError(error.InvalidFormat, err);
}

test "parse with literal characters" {
    var cases = [_]TestCase{
        .{ .string = "datetime 2021-02-18 17:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }) },
        .{ .string = "datetime 1970-01-01 00:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };
    for (cases) |case| {
        const dt = try str.parseDatetime("datetime %Y-%m-%d %H:%M:%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
        try std.testing.expect(dt.tzinfo == null);
    }

    cases = [_]TestCase{
        .{ .string = "2021-02-18 17:00:00 datetime", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }) },
        .{ .string = "1970-01-01 00:00:00 datetime", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };
    for (cases) |case| {
        const dt = try str.parseDatetime("%Y-%m-%d %H:%M:%S datetime", case.string);
        try std.testing.expectEqual(case.dt, dt);
        try std.testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{ .string = "2021-02-18 %% 17:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }) },
        .{ .string = "1970-01-01 %% 00:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };
    for (cases) |case| {
        const dt = try str.parseDatetime("%Y-%m-%d %%%% %H:%M:%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
        try std.testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{ .string = "%2021-02-18 17:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }) },
        .{ .string = "%1970-01-01 00:00:00", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };
    for (cases) |case| {
        const dt = try str.parseDatetime("%%%Y-%m-%d %H:%M:%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
        try std.testing.expect(dt.tzinfo == null);
    }
    cases = [_]TestCase{
        .{ .string = "2021-02-18 12%34%56", .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 12, 34, 56, 0 }) },
        .{ .string = "1970-01-01 00%00%00", .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }) },
    };
    for (cases) |case| {
        const dt = try str.parseDatetime("%Y-%m-%d %H%%%M%%%S", case.string);
        try std.testing.expectEqual(case.dt, dt);
        try std.testing.expect(dt.tzinfo == null);
    }
}

test "parse with z" {
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(3600, "");
    var dt_ref = try datetime.Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const s_hhmm = "2021-02-18T17:00:00+01:00";
    var dt = try str.parseDatetime("%Y-%m-%dT%H:%M:%S%z", s_hhmm);
    try std.testing.expectEqual(dt_ref.year, dt.year);

    var off_want = dt_ref.tzinfo.?.tzOffset.?.seconds_east;
    var off_have = dt.tzinfo.?.tzOffset.?.seconds_east;
    try std.testing.expect(off_have == 3600);
    try std.testing.expect(off_want == off_have);

    // with seconds in UTC offset
    try tzinfo.loadOffset(-3601, "");
    dt_ref = try datetime.Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tzinfo = tzinfo });
    const s_hhmmss = "2021-02-18T17:00:00-01:00:01";
    dt = try str.parseDatetime("%Y-%m-%dT%H:%M:%S%z", s_hhmmss);
    try std.testing.expectEqual(dt_ref.year, dt.year);

    off_want = dt_ref.tzinfo.?.tzOffset.?.seconds_east;
    off_have = dt.tzinfo.?.tzOffset.?.seconds_east;
    try std.testing.expect(off_have == -3601);
    try std.testing.expect(off_want == off_have);
}

test "string -> datetime -> string roundtrip with offset TZ" {
    var string_out = std.ArrayList(u8).init(std.testing.allocator);
    defer string_out.deinit();
    const string_in = "2023-12-09T01:02:03+09:15";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    const dt = try str.parseDatetime(directive, string_in);
    try str.formatDatetime(string_out.writer(), directive, dt);
    try std.testing.expectEqualStrings(string_in, string_out.items);
}
