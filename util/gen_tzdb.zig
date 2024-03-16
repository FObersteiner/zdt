//! Update eggert/tz submodule, build the time zone database and move
//! its 'zoneinfo' directory to /lib/tzdata.
const std = @import("std");
const log = std.log.scoped(.zdt__gen_tzdata);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // update submodule
    const argv_update = [_][]const u8{ "git", "submodule", "update", "--remote", "tz" };
    const proc_update = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = &argv_update,
    });

    // assert that there is no output to stderr, otherwise fail:
    if (proc_update.stderr.len > 0) {
        log.err("update command failed : {s}", .{proc_update.stderr});
        return error.UpdateFailed;
    }

    if (proc_update.stdout.len > 0) {
        log.info("submodule update stdout: {s}", .{proc_update.stdout});
    } else {
        log.info("submodule update: no updates available", .{});
        // TODO : could exit here if tz db update should not be forced
    }
    allocator.free(proc_update.stdout);
    allocator.free(proc_update.stderr);

    // in tz dir, run makefile
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip running binary name

    // where to run makefile
    const tzdir = args.next();

    // destination file path; need to expand this to a full path
    const target_dir = args.next();

    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_path);

    const source_dir_abs = try std.fs.path.resolve(allocator, &.{ cwd_path, tzdir.? });
    defer allocator.free(source_dir_abs);

    const tmp_dir = try std.fs.path.resolve(allocator, &.{ cwd_path, target_dir.?, "../tmp" });
    defer allocator.free(tmp_dir);

    const target_dir_abs = try std.fs.path.resolve(allocator, &.{ cwd_path, target_dir.? });
    defer allocator.free(target_dir_abs);

    log.info("tz dir, source: {s}", .{source_dir_abs});
    log.info("target, tmp: {s}", .{tmp_dir});
    log.info("target, final: {s}", .{target_dir_abs});

    var path_buffer: [std.fs.MAX_PATH_BYTES + 8]u8 = undefined;
    const target_dir_cmd = try std.fmt.bufPrint(&path_buffer, "DESTDIR={s}", .{tmp_dir});

    // compile tzdata
    const argv_compile = [_][]const u8{ "make", target_dir_cmd, "ZFLAGS=-b fat", "POSIXRULES=", "install" };
    const proc_compile = try std.ChildProcess.run(.{
        .cwd = source_dir_abs,
        .allocator = allocator,
        .argv = &argv_compile,
    });
    if (proc_compile.stdout.len > 0) {
        log.info("tzdb compile step, stdout: {s}", .{proc_compile.stdout});
    }
    if (proc_compile.stderr.len > 0) {
        log.info("tzdb compile step, stderr: {s}", .{proc_compile.stderr});
    }
    allocator.free(proc_compile.stdout);
    allocator.free(proc_compile.stderr);

    // copy [tmp_dir]/usr/share/zoneinfo target_dir_abs
    const target_dir_copy = try std.fmt.bufPrint(&path_buffer, "{s}/usr/share/zoneinfo", .{tmp_dir});

    var src_dir = try std.fs.cwd().openDir(target_dir_copy, .{ .iterate = true });
    errdefer src_dir.close();
    var dest_dir = try std.fs.cwd().makeOpenPath(target_dir_abs, .{});
    errdefer dest_dir.close();

    log.info("copy stuff from {s} to {s}", .{ target_dir_copy, target_dir_abs });

    var walker = try src_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                entry.dir.copyFile(entry.basename, dest_dir, entry.path, .{}) catch |err| {
                    log.warn("copy file: {}", .{err});
                };
            },
            .directory => {
                dest_dir.makeDir(entry.path) catch |err| {
                    log.warn("make dir: {}, path: {s}", .{ err, entry.path });
                };
            },
            else => return error.UnexpectedEntryKind,
        }
    }

    src_dir.close(); // error-deferred call to .close() before
    dest_dir.close();

    log.info("delete {s}", .{tmp_dir});

    var del_dir = try std.fs.cwd().openDir(tmp_dir, .{ .iterate = true });
    defer del_dir.close();
    try del_dir.deleteTree(tmp_dir);
}
