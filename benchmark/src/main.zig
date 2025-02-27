const std = @import("std");
const log = std.log.scoped(.zdt_benchmarks);

const bmarks_timer = @import("bmarks_timer.zig");
const bmarks_zbench = @import("bmarks_zbench.zig");

pub fn main() !void {
    _ = try bmarks_timer.run();

    _ = try bmarks_zbench.run();
}
