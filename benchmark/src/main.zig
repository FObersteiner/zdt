const std = @import("std");
const log = std.log.scoped(.zdt_benchmarks);

const bmarks_timer = @import("bmarks_timer.zig");
const bmarks_zbench = @import("bmarks_zbench.zig");

pub fn main() !void {
    log.warn("\n+++ Timer benchmarks +++", .{});
    _ = try bmarks_timer.run();

    log.warn("\n+++ zbench benchmarks +++", .{});
    _ = try bmarks_zbench.run();
}
