//! Update eggert/tz submodule, build the time zone database and move
//! its 'zoneinfo' directory to /lib/tzdata. Remove all other build artifacts.
//
// to add the submodule, run `git submodule add -f https://github.com/eggert/tz ./tz`
const std = @import("std");
const log = std.log.scoped(.zdt__gen_tzdb);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip running binary name
    // tag to check out
    const tzdbtag = args.next();

    // update submodule
    const argv_update = [_][]const u8{
        "git",
        "submodule",
        "update",
        "--init", // --init and
        "--recursive", // --recursive flags used here to work around a pyenv bug
        "--remote",
        "./tz",
    };
    const proc_update = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv_update,
    });

    if (proc_update.stderr.len > 0) {
        log.err("update command failed : {s}", .{proc_update.stderr});
        // error might originate from pyenv bug... try to continue.
    }

    if (proc_update.stdout.len > 0) {
        log.info("submodule update stdout: {s}", .{proc_update.stdout});
    } else {
        log.info("submodule update: no updates available", .{});
        // TODO : consider 'force' flag (issue #4): exit here if tz db update should not be forced
    }
    allocator.free(proc_update.stdout);
    allocator.free(proc_update.stderr);

    log.info("tz database tag: {s}", .{tzdbtag.?});
    const argv_tagcheckout = [_][]const u8{
        "git",
        "-C",
        "./tz",
        "checkout",
        tzdbtag.?,
    };
    const proc_tag = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv_tagcheckout,
    });

    if (proc_tag.stderr.len > 0) {
        log.err("update command failed : {s}", .{proc_update.stderr});
    }
    if (proc_tag.stdout.len > 0) {
        log.info("submodule update stdout: {s}", .{proc_update.stdout});
    }
    allocator.free(proc_tag.stdout);
    allocator.free(proc_tag.stderr);
    // in tz dir, run makefile

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

    var path_buffer: [std.fs.max_path_bytes + 8]u8 = undefined;
    const target_dir_cmd = try std.fmt.bufPrint(&path_buffer, "DESTDIR={s}", .{tmp_dir});

    // compile tzdata
    const argv_compile = [_][]const u8{ "make", target_dir_cmd, "ZFLAGS=-b fat", "POSIXRULES=", "install" };
    const proc_compile = try std.process.Child.run(.{
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

    const proc_wintzmapping = try std.process.Child.run(.{
        .cwd = source_dir_abs,
        .allocator = allocator,
        .argv = &[_][]const u8{
            "python",
            "../util/gen_wintz_mapping.py",
        },
    });
    if (proc_wintzmapping.stdout.len > 0) {
        log.info("tzdb make win tz mappeing step, stdout: {s}", .{proc_wintzmapping.stdout});
    }
    if (proc_wintzmapping.stderr.len > 0) {
        log.info("tzdb make win tz mappeing step, stderr: {s}", .{proc_wintzmapping.stderr});
    }
    allocator.free(proc_wintzmapping.stdout);
    allocator.free(proc_wintzmapping.stderr);

    const proc_tzembed = try std.process.Child.run(.{
        .cwd = source_dir_abs,
        .allocator = allocator,
        .argv = &[_][]const u8{
            "python",
            "../util/gen_tzdb_embedding.py",
            tzdbtag.?,
        },
    });
    if (proc_tzembed.stdout.len > 0) {
        log.info("tzdb embedding mappeing step, stdout: {s}", .{proc_tzembed.stdout});
    }
    if (proc_tzembed.stderr.len > 0) {
        log.info("tzdb embedding step, stderr: {s}", .{proc_tzembed.stderr});
    }
    allocator.free(proc_tzembed.stdout);
    allocator.free(proc_tzembed.stderr);

    return std.process.cleanExit();
}
