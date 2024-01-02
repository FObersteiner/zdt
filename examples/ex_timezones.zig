const std = @import("std");
const print = std.debug.print;

const zdt = @import("zdt");
const dt = zdt.datetime;
const tz = zdt.timezone;
const dtstr = zdt.stringIO;

test "time zones demo" {
    print("\n---> time zones demo", .{});

    print("\n TZ type info:", .{});
    print("size of {s}: {}\n", .{ @typeName(tz.TZ), @sizeOf(tz.TZ) });
    inline for (std.meta.fields(tz.TZ)) |field| {
        std.debug.print("  field {s} byte offset: {}\n", .{ field.name, @offsetOf(tz.TZ, field.name) });
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("\nGPA deinit output: {}\n", .{gpa.deinit()});
    var logging_alloc = std.heap.loggingAllocator(gpa.allocator());
    const allocator = logging_alloc.allocator();

    var tzinfo = try tz.fromTzfile("localtime", allocator);
    defer tzinfo.deinit();

    const now_local = dt.Datetime.now(tzinfo);
    print("\nNow, local : {s}\n", .{now_local});

    try tzinfo.loadTzfile("America/New_York", allocator);
    const now_ny = try now_local.tzConvert(tzinfo);
    print("Now in New York : {s}\n", .{now_ny});
    print("Wall time difference, local->NY: {}\n", .{try now_ny.diffWall(now_local)});

    print("\nNew York has DST currently? : {}\n", .{now_ny.tzinfo.?.is_dst});
    const a_date = try dtstr.parseDatetime("%Y-%m-%d", "2023-8-9");
    const ny_summer_2023 = try a_date.tzLocalize(tzinfo);
    print("New York, summer : {s}\n", .{ny_summer_2023});
    print("New York has DST in summer? : {}\n", .{ny_summer_2023.tzinfo.?.is_dst});
}
