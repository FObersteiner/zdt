const std = @import("std");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Tz = zdt.Timezone;
const str = zdt.stringIO;

pub fn main() !void {
    println("---> time zones example", .{});
    println("", .{});

    println("TZ type info:", .{});
    println("size of {s}: {}", .{ @typeName(Tz), @sizeOf(Tz) });
    inline for (std.meta.fields(Tz)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Tz, field.name) });
    }
    println("", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tz: Tz = try Tz.fromTzfile("localtime", allocator);
    defer tz.deinit();

    const now_local: Datetime = Datetime.now(tz);
    println("Now, local : {s} ({s})", .{ now_local, now_local.tzinfo.?.abbreviation });

    try tz.loadTzfile("America/New_York", allocator);
    const now_ny: Datetime = try now_local.tzConvert(tz);
    println("Now in New York : {s} ({s})", .{ now_ny, now_ny.tzinfo.?.abbreviation });
    println("Wall time difference, local vs. NY: {}", .{try now_ny.diffWall(now_local)});

    println("New York has DST currently? : {}", .{now_ny.tzinfo.?.is_dst});
    const a_date: Datetime = try str.parseDatetime("%Y-%m-%d", "2023-8-9");
    const ny_summer_2023: Datetime = try a_date.tzLocalize(tz);
    println("New York, summer : {s} ({s})", .{ ny_summer_2023, ny_summer_2023.tzinfo.?.abbreviation });
    println("New York has DST in summer? : {}", .{ny_summer_2023.tzinfo.?.is_dst});
    std.debug.assert(std.mem.eql(u8, ny_summer_2023.tzinfo.?.abbreviation, "EDT"));
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
