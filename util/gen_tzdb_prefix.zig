//! Update the path to the IANA time zone database shipped with zdt.
const std = @import("std");
const log = std.log.scoped(.zdt__gen_tzdb_prefix);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip running binary name

    const default = args.next().?;
    const user_specified = args.next().?;

    const tmp = if (std.mem.eql(u8, default, user_specified))
        default
    else
        user_specified;

    const prefix = try allocator.dupe(u8, tmp);
    // POSIX sep 'should' work on Windows while backslash fails in any case.
    std.mem.replaceScalar(u8, prefix, '\\', '/');
    defer allocator.free(prefix);

    // log.info("tzdb prefix: {s}", .{prefix});

    // filename arg passed in from build.zig
    const filename = args.next().?;
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();

    try writer.writeAll(
        \\// This file is auto-generated. Do not edit!
        \\//
        \\// This file is also specific to your copy of zdt;
        \\// it is not part of the git repository.
        \\//
    );
    try writer.print("\npub const tzdb_prefix = \"{s}\";", .{prefix});

    try bw.flush();

    return std.process.cleanExit();
}
