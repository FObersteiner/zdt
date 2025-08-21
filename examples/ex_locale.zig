const std = @import("std");
const builtin = @import("builtin");
const c_locale = @cImport(@cInclude("locale.h"));

const zdt = @import("zdt");
const Datetime = zdt.Datetime;

pub fn main() !void {
    println("---> locale example", .{});

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

    var buf: [32]u8 = std.mem.zeroes([32]u8);
    var w: std.Io.Writer = .fixed(&buf);

    // datetime to string
    //
    try dt.toString("%a, %b %d %Y, %H:%Mh", &w);
    println("", .{});
    println("formatted {f}\n  to '{s}'", .{ dt, buf });

    w = std.Io.Writer.fixed(&buf);
    try dt.toString("%A, %B %d %Y, %H:%Mh", &w);
    println("", .{});
    println("formatted {f}\n  to '{s}'", .{ dt, buf });

    // string to datetime
    //
    const input = "Mittwoch, 23. Januar 1974, 03:17h";
    const parsed = try Datetime.fromString(input, "%A, %d. %B %Y, %H:%Mh");
    println("", .{});
    println("parsed '{s}'\n  to '{f}'", .{ input, parsed });

    // by adding a modifier character, you can always parse English month names,
    // independent of the locale:
    const input_eng = "Wednesday, January 23 1974, 03:17h";
    const parsed_eng = try Datetime.fromString(input_eng, "%:A, %:B %d %Y, %H:%Mh");
    println("", .{});
    println("parsed '{s}'\n  to '{f}'", .{ input_eng, parsed_eng });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    var writer = &stdout.interface;
    writer.print(fmt ++ "\n", args) catch return;
}
