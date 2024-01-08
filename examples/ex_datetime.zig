const std = @import("std");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Tz = zdt.Timezone;
const str = zdt.stringIO;

pub fn main() !void {
    println("---> datetime example", .{});
    println("", .{});

    println("datetime type info:", .{});
    println("size of {s}: {}", .{ @typeName(Datetime), @sizeOf(Datetime) });
    inline for (std.meta.fields(Datetime)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Datetime, field.name) });
    }
    println("", .{});

    println("---> (usage) Unix epoch: datetime from timestamp", .{});
    const unix_epoch = try Datetime.fromUnix(0, Duration.Resolution.second, null);
    println("'Unix epoch', naive datetime : {s}", .{unix_epoch});
    const unix_epoch_correct = try Datetime.fromUnix(0, Duration.Resolution.second, Tz.UTC);
    println("'Unix epoch', aware datetime : {s}", .{unix_epoch_correct});
    println("'Unix epoch', tz name : {s}", .{unix_epoch_correct.tzinfo.?.name});

    println("", .{});
    println("---> (usage) Now: datetime from system time", .{});
    const now = Datetime.utcnow();
    println("'now', UTC      : {s}", .{now});
    const now_s = try now.floorTo(Duration.Timespan.second);
    println("(nanos removed) : {s}", .{now_s});
    const now_date = try now.floorTo(Duration.Timespan.day);
    println("         (date) : {s}", .{now_date});

    println("", .{});
    println("---> (usage) ISO8601: parse some allowed formats", .{});
    const date_only = "2014-08-23";
    var parsed = try str.parseISO8601(date_only);
    println("parsed '{s}' to {s}", .{ date_only, parsed });
    const datetime_with_frac = "2014-08-23 12:15:56,1234";
    parsed = try str.parseISO8601(datetime_with_frac);
    println("parsed '{s}' to {s}", .{ datetime_with_frac, parsed });
    const leap_datetime = "2016-12-31T23:59:60Z";
    parsed = try str.parseISO8601(leap_datetime);
    println("parsed '{s}' to {s}", .{ leap_datetime, parsed });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
