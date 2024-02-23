//! Update the version information of the IANA time zone database shipped with zdt.
const std = @import("std");
const log = std.log.scoped(.zdt__gen_tzversion);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // get latest tag of tz database
    // NOTE : this could also be obtained from tzdata.zi in the tz directory (first line)
    const argv = [_][]const u8{ "git", "describe", "--tags" }; // , "--abbrev=0" // <-- remove commit hash
    const proc = try std.ChildProcess.run(.{
        .cwd = "./tz",
        .allocator = allocator,
        .argv = &argv,
    });

    // on success, we own the output streams
    defer allocator.free(proc.stdout);
    defer allocator.free(proc.stderr);

    log.info("tzdb version: {s}", .{proc.stdout});

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // Skip running binary name

    // filename arg passed in from build.zig
    const filename = args.next().?;
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();

    try writer.writeAll("// This file is auto-generated. Do not edit.\n\n");
    try writer.print(
        "pub const tzdb_version = \"{s}\";\n",
        .{proc.stdout[0 .. proc.stdout.len - 1]},
    );

    try bw.flush();
}
