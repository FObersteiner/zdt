//! test datetime <--> string
const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.zdt_test_formats);

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Timezone = zdt.Timezone;
const Formats = zdt.Formats;

const TestCase = struct {
    string: []const u8,
    dt: Datetime,
    directive: []const u8 = "",
};

test "format datetime with pre-defined formats" {
    const cases = [_]TestCase{
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.ANSIC,
            .string = "Mon Feb  1 17:00:00 2021",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.UnixDate,
            .string = "Mon Feb  1 17:00:00 UTC 2021",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RubyDate,
            .string = "Mon Feb  1 17:00:00 +0000 2021",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC822,
            .string = "01 Feb 21 17:00 UTC",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC822Z,
            .string = "01 Feb 21 17:00 +0000",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC850,
            .string = "Monday, 01-Feb-21 17:00:00 UTC",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC1123,
            .string = "Mon, 01 Feb 2021 17:00:00 UTC",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 1, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC1123Z,
            .string = "Mon, 01 Feb 2021 17:00:00 +0000",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC3339,
            .string = "2021-02-18T17:00:00+00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.RFC3339nano,
            .string = "2021-02-18T17:00:00.000000000+00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.DateOnly,
            .string = "2021-02-18",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.TimeOnly,
            .string = "17:00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 18, .hour = 17, .tz_options = .{ .tz = &Timezone.UTC } }),
            .directive = Formats.DateTime,
            .string = "2021-02-18 17:00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 8, .hour = 17, .nanosecond = 123456789 }),
            .directive = Formats.Stamp,
            .string = "Feb  8 17:00:00",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 8, .hour = 17, .nanosecond = 123456789 }),
            .directive = Formats.StampMilli,
            .string = "Feb  8 17:00:00.123",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 8, .hour = 17, .nanosecond = 123456789 }),
            .directive = Formats.StampMicro,
            .string = "Feb  8 17:00:00.123456",
        },
        .{
            .dt = try Datetime.fromFields(.{ .year = 2021, .month = 2, .day = 8, .hour = 17, .nanosecond = 123456789 }),
            .directive = Formats.StampNano,
            .string = "Feb  8 17:00:00.123456789",
        },
    };

    const sz: usize = 64;
    var buf: [sz]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    inline for (cases) |case| {
        _ = w.consumeAll();
        buf = std.mem.zeroes([sz]u8);
        try case.dt.toString(case.directive, &w);
        try testing.expectEqualStrings(case.string, std.mem.sliceTo(&buf, 0));
    }
}
