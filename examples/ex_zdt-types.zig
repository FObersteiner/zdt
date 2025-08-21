const std = @import("std");
const builtin = @import("builtin");

const zdt = @import("zdt");
const Datetime = zdt.Datetime;
const Duration = zdt.Duration;
const Timezone = zdt.Timezone;
const UTCoffset = zdt.UTCoffset;

pub fn main() !void {
    println("OS: {s}, architecture: {s}", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    println("Zig version: {s}\n", .{builtin.zig_version_string});

    println("---> Datetime", .{});
    println("size of {s}: {} bytes", .{ @typeName(Datetime), @sizeOf(Datetime) });
    inline for (std.meta.fields(Datetime)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Datetime, field.name) });
    }
    println("", .{});

    println("---> Duration", .{});
    println("size of {s}: {} bytes", .{ @typeName(Duration), @sizeOf(Duration) });
    inline for (std.meta.fields(Duration)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Duration, field.name) });
    }
    println("", .{});

    println("---> Timezone", .{});
    println("size of {s}: {} bytes", .{ @typeName(Timezone), @sizeOf(Timezone) });
    inline for (std.meta.fields(Timezone)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(Timezone, field.name) });
    }
    println("", .{});

    println("---> Timezone Database", .{});
    println("  {d} bytes", .{Timezone.sizeOfTZdata()});
    println("", .{});

    println("---> UTCoffset", .{});
    println("size of {s}: {} bytes", .{ @typeName(UTCoffset), @sizeOf(UTCoffset) });
    inline for (std.meta.fields(UTCoffset)) |field| {
        println("  field {s} byte offset: {}", .{ field.name, @offsetOf(UTCoffset, field.name) });
    }
    println("", .{});
}

fn println(comptime fmt: []const u8, args: anytype) void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    var writer = &stdout.interface;
    writer.print(fmt ++ "\n", args) catch return;
}
