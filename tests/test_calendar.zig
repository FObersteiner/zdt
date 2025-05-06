//! test calendric calculations

const std = @import("std");
const testing = std.testing;

const zdt = @import("zdt");
const Datetime = zdt.Datetime;

const log = std.log.scoped(.test_calendar);

test "Easter, Gregorian" {
    var dt = try Datetime.fromFields(.{ .year = 1970 });
    try testing.expectEqual(
        try Datetime.fromFields(.{ .year = 1970, .month = 3, .day = 29 }),
        try Datetime.EasterDate(dt.year),
    );

    dt = try Datetime.fromFields(.{ .year = 2009 });
    try testing.expectEqual(
        try Datetime.fromFields(.{ .year = 2009, .month = 4, .day = 12 }),
        try Datetime.EasterDate(dt.year),
    );

    dt = try Datetime.fromFields(.{ .year = 2018 });
    try testing.expectEqual(
        try Datetime.fromFields(.{ .year = 2018, .month = 4, .day = 1 }),
        try Datetime.EasterDate(dt.year),
    );

    dt = try Datetime.fromFields(.{ .year = 2025 });
    try testing.expectEqual(
        try Datetime.fromFields(.{ .year = 2025, .month = 4, .day = 20 }),
        try Datetime.EasterDate(dt.year),
    );

    dt = try Datetime.fromFields(.{ .year = 2160 });
    try testing.expectEqual(
        try Datetime.fromFields(.{ .year = 2160, .month = 3, .day = 23 }),
        try Datetime.EasterDate(dt.year),
    );
}
