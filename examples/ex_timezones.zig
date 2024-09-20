const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Tz = zdt.Timezone;

pub fn main() !void {
    println("---> time zones example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    println("TZ type info:", .{});
    println("size of {s}: {}", .{ @typeName(Tz), @sizeOf(Tz) });
    inline for (std.meta.fields(Tz)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Tz, field.name) });
    }
    println("", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    println("time zone database version: {s}\n", .{Tz.tzdb_version});

    var tz_berlin: Tz = try Tz.fromTzdata("Europe/Berlin", allocator);
    defer tz_berlin.deinit();
    var now_berlin: Datetime = try Datetime.now(tz_berlin);
    const now_utc: Datetime = Datetime.nowUTC();
    println("Now, UTC time    : {s}", .{now_utc});
    println("Now, Berlin time : {s} ({s})", .{ now_berlin, now_berlin.tzinfo.?.abbreviation() });
    println("Datetimes have timezone? {}, {}\n", .{ now_utc.isAware(), now_berlin.isAware() });

    var my_tz: Tz = try Tz.tzLocal(allocator);
    defer my_tz.deinit();
    var now_local = try now_berlin.tzConvert(my_tz);
    println("My time zone : {s}", .{my_tz.name()});

    println("Now, my time zone : {s} ({s})", .{ now_local, now_local.tzinfo.?.abbreviation() });
    println("", .{});

    var tz_ny = try Tz.fromTzdata("America/New_York", allocator);
    defer tz_ny.deinit();
    var now_ny: Datetime = try now_local.tzConvert(tz_ny);
    println("Now in New York : {s} ({s})", .{ now_ny, now_ny.tzinfo.?.abbreviation() });
    println("Wall time difference, local vs. NY: {}", .{try now_ny.diffWall(now_local)});
    println("", .{});

    println("New York has DST currently? : {}", .{now_ny.tzinfo.?.tzOffset.?.is_dst});
    var ny_summer_2023: Datetime = try Datetime.fromFields(.{
        .year = 2023,
        .month = 8,
        .day = 9,
        .tzinfo = tz_ny,
    });
    println("New York, summer : {s} ({s})", .{ ny_summer_2023, ny_summer_2023.tzinfo.?.abbreviation() });
    println("New York has DST in summer? : {}", .{ny_summer_2023.tzinfo.?.tzOffset.?.is_dst});
    println("", .{});

    // non-existing datetime: DST gap
    // always errors:
    const err_ne = Datetime.fromFields(.{ .year = 2024, .month = 3, .day = 10, .hour = 2, .minute = 30, .tzinfo = tz_ny });
    println("Attempt to create non-existing datetime: {any}", .{err_ne});

    // ambiguous datetime: DST fold
    // errors if 'dst_fold' is undefined:
    const err_amb = Datetime.fromFields(.{ .year = 2024, .month = 11, .day = 3, .hour = 1, .minute = 30, .tzinfo = tz_ny });
    println("Attempt to create ambiguous datetime: {any}", .{err_amb});
    // we can specify on which side of the fold the datetime should fall:
    const amb_dt_early = try Datetime.fromFields(.{ .year = 2024, .month = 11, .day = 3, .hour = 1, .minute = 30, .dst_fold = 0, .tzinfo = tz_ny });
    println("Ambiguous datetime, early side of fold: {s}", .{amb_dt_early});
    const amb_dt_late = try Datetime.fromFields(.{ .year = 2024, .month = 11, .day = 3, .hour = 1, .minute = 30, .dst_fold = 1, .tzinfo = tz_ny });
    println("Ambiguous datetime, late side of fold: {s}", .{amb_dt_late});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
