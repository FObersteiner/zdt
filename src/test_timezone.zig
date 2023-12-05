const std = @import("std");
const zdt = @import("zdt.zig");

test "tz" {
    // if (true) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = zdt.zone.Tz{};
    _ = try t.load_tzfile("America/Denver", allocator);
    std.debug.print("\n(Am. Den.) name {s}", .{t.name});
    // std.debug.print("POSIX parsed {any}", .{t.posixRule.?});
    // log.warn("{s}", .{t.posixrule.?.std_designation});
    // log.warn("{s}", .{t.posixrule.?.dst_designation});
    // std.debug.print("{any}", .{t.posixRule.?.std_offset});
    // std.debug.print("{any}", .{t.posixRule.?.dst_offset});
    var off = try t.offset_from_unix(@intCast(std.time.timestamp()));
    std.debug.print("\n(Am. Den.) {any}", .{off});
    std.debug.print("\n(Am. Den.) {s}", .{try off.to_offset_string()});

    _ = try t.load_tzfile("UTC", allocator);
    std.debug.print("\n(UTC) name {s}", .{t.name});
    // std.debug.print("(UTC) POSIX parsed {any}", .{t.posixRule.?});
    // // log.warn("(UTC) {s}", .{t.posixRule.?.std_designation});
    // // log.warn("(UTC) {s}", .{t.posixRule.?.dst_designation});
    // std.debug.print("(UTC) {any}", .{t.posixRule.?.std_offset});
    // std.debug.print("(UTC) {any}", .{t.posixRule.?.dst_offset});
    off = try t.offset_from_unix(@intCast(std.time.timestamp()));
    std.debug.print("\n(UTC) {any}", .{off});
    std.debug.print("\n(UTC) {s}", .{try off.to_offset_string()});
}
