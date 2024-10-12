const std = @import("std");
const builtin = @import("builtin");
const c_locale = @cImport(@cInclude("locale.h"));

const zdt = @import("zdt");
const Datetime = zdt.Datetime;

pub fn main() !void {
    println("---> locale example", .{});
    println("OS / architecture: {s} / {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}", .{builtin.zig_version_string});

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
        std.log.err("skip example, failed to set locale", .{});
    }

    const dt = try Datetime.fromISO8601("2024-10-12");

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try dt.toString("%a, %b %d %Y, %H:%Mh", buf.writer());
    println("", .{});
    println("formatted {s}\n  to '{s}'", .{ dt, buf.items });

    buf.clearAndFree();

    try dt.toString("%A, %B %d %Y, %H:%Mh", buf.writer());
    println("", .{});
    println("formatted {s}\n  to '{s}'", .{ dt, buf.items });
}

fn println(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt ++ "\n", args) catch return;
}
