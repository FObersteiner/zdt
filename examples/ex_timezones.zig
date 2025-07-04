const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Timezone = zdt.Timezone;

pub fn main() !void {
    println("---> time zones example", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    println("IANA time zone database version: {s}", .{Timezone.tzdb_version});
    println("path to local tz database: {s}\n", .{Timezone.tzdb_prefix});

    println("load timezone, dynamically allocated memory:", .{});
    var tz_berlin: Timezone = try Timezone.fromTzdata("Europe/Berlin", allocator);
    defer tz_berlin.deinit();
    println("Info: {any}", .{tz_berlin});
    var now_berlin: Datetime = try Datetime.now(.{ .tz = &tz_berlin });
    const now_utc: Datetime = Datetime.nowUTC();
    println("Now, UTC time    : {s}", .{now_utc});
    println("Now, Berlin time : {s:.0} ({s})", .{ now_berlin, now_berlin.tzAbbreviation() });
    println("Datetimes have UTC offset / time zone? : {}, {}\n", .{ now_utc.isAware(), now_berlin.isAware() });

    println("load timezone, static memory:", .{});
    const tz_berlin_: Timezone = try Timezone.fromTzdata("Europe/Berlin", null);
    println("Info: {any}", .{tz_berlin_});
    const now_berlin_: Datetime = try Datetime.now(.{ .tz = &tz_berlin_ });
    println("Now, Berlin time : {s:.0} ({s})\n", .{ now_berlin_, now_berlin_.tzAbbreviation() });

    var my_tz: Timezone = try Timezone.tzLocal(allocator);
    defer my_tz.deinit();
    var now_local = try now_berlin.tzConvert(.{ .tz = &my_tz });
    println("My time zone : {s}", .{my_tz.name()});

    println("Now, my time zone : {s:.0} ({s})", .{ now_local, now_local.tzAbbreviation() });
    println("", .{});

    var tz_ny = try Timezone.fromTzdata("America/New_York", allocator);
    defer tz_ny.deinit();
    var now_ny: Datetime = try now_local.tzConvert(.{ .tz = &tz_ny });
    println("Now in New York : {s:.0} ({s})", .{ now_ny, now_ny.tzAbbreviation() });
    println("Wall time difference, local vs. NY: {}", .{try now_ny.diffWall(now_local)});
    println("", .{});

    println("New York has DST currently? : {}", .{now_ny.isDST()});
    const ny_summer_2023: Datetime = try Datetime.fromFields(.{
        .year = 2023,
        .month = 8,
        .tz_options = .{ .tz = &tz_ny },
    });
    println("New York, summer : {s} ({s})", .{ ny_summer_2023, ny_summer_2023.tzAbbreviation() });
    const ny_winter_2023: Datetime = try Datetime.fromFields(.{
        .year = 2023,
        .month = 12,
        .tz_options = .{ .tz = &tz_ny },
    });
    println("New York, winter : {s} ({s})", .{ ny_winter_2023, ny_winter_2023.tzAbbreviation() });
    println("New York has DST in summer? : {}", .{ny_summer_2023.isDST()});
    println("", .{});

    // non-existing datetime: DST gap
    // always errors:
    const err_ne = Datetime.fromFields(.{ .year = 2024, .month = 3, .day = 10, .hour = 2, .minute = 30, .tz_options = .{ .tz = &tz_ny } });
    println("Attempt to create non-existing datetime: {any}", .{err_ne});

    // ambiguous datetime: DST fold
    // errors if 'dst_fold' is undefined:
    const err_amb = Datetime.fromFields(.{
        .year = 2024,
        .month = 11,
        .day = 3,
        .hour = 1,
        .minute = 30,
        .tz_options = .{ .tz = &tz_ny },
    });
    println("Attempt to create ambiguous datetime: {any}", .{err_amb});
    // we can specify on which side of the fold the datetime should fall:
    const amb_dt_early = try Datetime.fromFields(.{
        .year = 2024,
        .month = 11,
        .day = 3,
        .hour = 1,
        .minute = 30,
        .dst_fold = 0,
        .tz_options = .{ .tz = &tz_ny },
    });
    println("Ambiguous datetime, early side of fold: {s}", .{amb_dt_early});
    const amb_dt_late = try Datetime.fromFields(.{
        .year = 2024,
        .month = 11,
        .day = 3,
        .hour = 1,
        .minute = 30,
        .dst_fold = 1,
        .tz_options = .{ .tz = &tz_ny },
    });
    println("Ambiguous datetime, late side of fold: {s}", .{amb_dt_late});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
