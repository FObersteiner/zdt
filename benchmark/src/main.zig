const std = @import("std");
const print = std.debug.print;
const pbs = @import("parser_isoformat.zig");

pub fn main() !void {
    _ = try pbs.run_isoparse_bench_simple();
}
