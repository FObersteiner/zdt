const std = @import("std");
const builtin = @import("builtin");
const c_locale = @cImport(@cInclude("locale.h"));

const zdt = @import("zdt");
const Datetime = zdt.Datetime;

pub fn main() !void {
    println("---> locale example", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const time_mask = switch (builtin.os.tag) {
        .linux, .windows => c_locale.LC_ALL,
        else => c_locale.LC_TIME,
    };

    const loc = "de_DE.UTF-8";
    const new_loc = c_locale.setlocale(time_mask, loc);
    if (new_loc == null) {
        // Zig 0.14:
        // std.process.fatal("skip example, failed to set locale", .{});
        std.log.err("skip example, failed to set locale", .{});
    }

    const dt = try Datetime.fromISO8601("2024-10-12");

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // datetime to string
    //
    try dt.toString("%a, %b %d %Y, %H:%Mh", buf.writer());
    println("", .{});
    println("formatted {s}\n  to '{s}'", .{ dt, buf.items });

    buf.clearAndFree();

    try dt.toString("%A, %B %d %Y, %H:%Mh", buf.writer());
    println("", .{});
    println("formatted {s}\n  to '{s}'", .{ dt, buf.items });

    // string to datetime
    //
    const input = "Mittwoch, 23. Januar 1974, 03:17h";
    const parsed = try Datetime.fromString(input, "%A, %d. %B %Y, %H:%Mh");
    println("", .{});
    println("parsed '{s}'\n  to '{s}'", .{ input, parsed });

    // by adding a modifier character, you can always parse English month names,
    // independent of the locale:
    const input_eng = "Wednesday, January 23 1974, 03:17h";
    const parsed_eng = try Datetime.fromString(input_eng, "%:A, %:B %d %Y, %H:%Mh");
    println("", .{});
    println("parsed '{s}'\n  to '{s}'", .{ input_eng, parsed_eng });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
