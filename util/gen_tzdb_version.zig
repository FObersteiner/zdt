//! Update the version information of the IANA time zone database shipped with zdt.
const std = @import("std");
const log = std.log.scoped(.zdt__gen_tzdb_version);

pub fn main() !void {
    // changed in v0.1.22: get the version info from the tzdata.zi file.
    // if this file does not exist, generation of the version file (tzdb_version.zig)
    // should fail - no data, no version!
    var zifile = try std.fs.cwd().openFile("lib/tzdata/zoneinfo/tzdata.zi", .{});
    defer zifile.close();
    var buf_reader = std.io.bufferedReader(zifile.reader());
    var in_stream = buf_reader.reader();
    var buf: [128]u8 = undefined;
    const line = (try in_stream.readUntilDelimiterOrEof(&buf, '\n')).?;
    var iterator = std.mem.splitScalar(u8, line, ' ');
    var version_string: []const u8 = undefined;
    while (iterator.next()) |x| {
        version_string = x;
    }
    // version must at least consist of a 4-digit year + letter code:
    std.debug.assert(version_string.len >= 5);
    log.info("time zone database version: {s}", .{version_string});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    // filename arg passed in from build.zig
    const filename = args.next().?;
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();

    try writer.writeAll("// This file is auto-generated. Do not edit.\n\n");
    try writer.writeAll("/// Version of the IANA time zone database shipped with zdt;\n");
    try writer.writeAll("/// year/version (letter code) and commit hash from eggert/tz\n");
    try writer.print("pub const tzdb_version = \"{s}\";\n", .{version_string});

    try bw.flush();
}
