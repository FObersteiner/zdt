const std = @import("std");
const zdt = @import("zdt.zig");

test "tz" {
    // if (true) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t = zdt.zone.Tz{};
    _ = try t.load("America/Denver", allocator);
    std.debug.print("(Am. Den.) name {s}", .{t.name});
    std.debug.print("POSIX parsed {any}", .{t.posixrule.?});
    // log.warn("{s}", .{t.posixrule.?.std_designation});
    // log.warn("{s}", .{t.posixrule.?.dst_designation});
    std.debug.print("{any}", .{t.posixrule.?.std_offset});
    std.debug.print("{any}", .{t.posixrule.?.dst_offset});
    var off = t.offset_from_utc(@intCast(std.time.timestamp()));
    std.debug.print("{any}", .{off});

    _ = try t.load("UTC", allocator);
    std.debug.print("(UTC) name {s}", .{t.name});
    std.debug.print("(UTC) POSIX parsed {any}", .{t.posixrule.?});
    // log.warn("(UTC) {s}", .{t.posixrule.?.std_designation});
    // log.warn("(UTC) {s}", .{t.posixrule.?.dst_designation});
    std.debug.print("(UTC) {any}", .{t.posixrule.?.std_offset});
    std.debug.print("(UTC) {any}", .{t.posixrule.?.dst_offset});
    off = t.offset_from_utc(@intCast(std.time.timestamp()));
    std.debug.print("(UTC) {any}", .{off});
}
