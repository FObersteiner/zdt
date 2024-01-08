const std = @import("std");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Tz = zdt.Timezone;
const str = zdt.stringIO;

pub fn main() !void {
    println("---> UTC offset time zone example", .{});
    println("", .{});

    const tzinfo = try Tz.fromOffset(3600, "UTC+1");
    const a_date = try Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    println("datetime: {s}", .{a_date});
    println("tz name: {s}", .{a_date.tzinfo.?.name});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var s = std.ArrayList(u8).init(gpa.allocator());
    defer s.deinit();

    try str.formatDatetime(s.writer(), "%Y-%m-%d", a_date);
    println("formatted date-only: {s}", .{s.items});

    const other_tzinfo = try Tz.fromOffset(-5 * 3600, "UTC-5");
    const a_date_other_tz = try a_date.tzConvert(other_tzinfo);
    println("datetime in other tz: {s}", .{a_date_other_tz});
    println("other tz name: {s}", .{a_date_other_tz.tzinfo.?.name});
    s.clearAndFree();
    try str.formatDatetime(s.writer(), "%Y-%m-%d, %Hh", a_date_other_tz);
    println("formatted: {s}\n", .{s.items});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
