//! A set of rules to describe date and time somewhere on earth, relative to universal time (UTC).

const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.zdt__Timezone);

const Datetime = @import("./Datetime.zig");
const UTCoffset = @import("./UTCoffset.zig");
const TzError = @import("./errors.zig").TzError;
const tzif = @import("./tzif.zig");
const posix = @import("./posix.zig");
const tzwin = @import("./windows/windows_tz.zig");

const Timezone = @This();

/// embedded IANA time zone database (eggert/tz)
pub const tzdata = @import("./tzdata.zig").tzdata;

pub const tzdb_version = @import("./tzdata.zig").tzdb_version;

/// auto-generated prefix / path of the current eggert/tz database, as shipped with zdt
// anonymous import; see build.zig
pub const tzdb_prefix = @import("tzdb_prefix").tzdb_prefix;

/// Where to comptime-load IANA tz database files from
const comptime_tzdb_prefix = "./tzdata/zoneinfo/"; // IANA db as provided by the library

// longest tz name is 'America/Argentina/ComodRivadavia' --> 32 ASCII chars
const cap_name_data: usize = 32;

const ruleTypes = enum {
    tzif,
    posixtz,
    utc,
};

// 'internal' data for the name / identifier
__name_data: [cap_name_data]u8 = std.mem.zeroes([cap_name_data]u8),
__name_data_len: usize = 0,

/// rules for a time zone
rules: union(ruleTypes) {
    /// IANA tz-db/tzdata TZif file
    tzif: tzif.Tz,
    /// POSIX TZ string
    posixtz: posix.Tz,
    // UTC placeholder; constant offset of zero
    utc: struct {},
},

pub const UTC: Timezone = .{
    .rules = .{ .utc = .{} },
    .__name_data = [3]u8{ 'U', 'T', 'C' } ++ std.mem.zeroes([cap_name_data - 3]u8),
    .__name_data_len = 3,
};

/// A time zone's identifier name.
pub fn name(tz: *const Timezone) []const u8 {
    return std.mem.sliceTo(&tz.__name_data, 0);
}

/// Make a time zone from IANA tz database TZif data, taken from the embedded tzdata.
/// The caller must make sure to de-allocate memory used for storing the TZif file's content
/// by calling the deinit method of the returned TZ instance.
pub fn fromTzdata(identifier: []const u8, allocator: std.mem.Allocator) TzError!Timezone {
    if (!identifierValid(identifier)) return TzError.InvalidIdentifier;

    //    if (std.mem.eql(u8, identifier, "localtime")) return tzLocal(allocator);

    if (tzdata.get(identifier)) |TZifBytes| {
        var in_stream = std.io.fixedBufferStream(TZifBytes);
        const tzif_tz = tzif.Tz.parse(allocator, in_stream.reader()) catch
            return TzError.TZifUnreadable;

        // ensure that there is a footer: requires v2+ TZif files.
        _ = tzif_tz.footer orelse return TzError.BadTZifVersion;

        var tz = Timezone{ .rules = .{ .tzif = tzif_tz } };
        tz.__name_data_len = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
        @memcpy(tz.__name_data[0..tz.__name_data_len], identifier[0..tz.__name_data_len]);

        return tz;
    }
    return TzError.TzUndefined;
}

/// Make a time zone from a IANA tz database TZif file. The identifier must be comptime-known.
/// This method allows the usage of a user-supplied tzdata; that path has to be specified
/// via the tzdb_prefix option in the build.zig.
/// The caller must make sure to de-allocate memory used for storing the TZif file's content
/// by calling the deinit method of the returned TZ instance.
/// TODO : remove?
/// tz should either be obtained from embedded tzdata (compile time) or from TZif file of system (runtime)
pub fn fromTzfile(comptime identifier: []const u8, allocator: std.mem.Allocator) TzError!Timezone {
    if (!identifierValid(identifier)) return TzError.InvalidIdentifier;
    const data = @embedFile(comptime_tzdb_prefix ++ identifier);
    var in_stream = std.io.fixedBufferStream(data);
    const tzif_tz = tzif.Tz.parse(allocator, in_stream.reader()) catch
        return TzError.TZifUnreadable;

    // ensure that there is a footer: requires v2+ TZif files.
    _ = tzif_tz.footer orelse return TzError.BadTZifVersion;

    var tz = Timezone{ .rules = .{ .tzif = tzif_tz } };
    tz.__name_data_len = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
    @memcpy(tz.__name_data[0..tz.__name_data_len], identifier[0..tz.__name_data_len]);

    return tz;
}

/// Same as fromTzfile but for runtime-known tz identifiers.
pub fn runtimeFromTzfile(identifier: []const u8, db_path: []const u8, allocator: std.mem.Allocator) TzError!Timezone {
    if (!identifierValid(identifier)) return TzError.InvalidIdentifier;
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&path_buffer);
    const fb_alloc = fba.allocator();

    const p = std.fs.path.join(fb_alloc, &[_][]const u8{ db_path, identifier }) catch
        return TzError.InvalidIdentifier;

    const file = std.fs.openFileAbsolute(p, .{}) catch
        return TzError.TZifUnreadable;
    defer file.close();

    const tzif_tz = tzif.Tz.parse(allocator, file.reader()) catch
        return TzError.TZifUnreadable;

    // ensure that there is a footer: requires v2+ TZif files.
    _ = tzif_tz.footer orelse return TzError.BadTZifVersion;

    var tz = Timezone{ .rules = .{ .tzif = tzif_tz } };
    // default: use identifier as name
    tz.__name_data_len = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
    @memcpy(tz.__name_data[0..tz.__name_data_len], identifier[0..tz.__name_data_len]);

    // if db_path is empty: assume identifier is a path
    // --> look for 'zoneinfo' substring in identifier, remove if found
    if (std.mem.eql(u8, db_path, "")) {
        var pathname_iterator = std.mem.splitSequence(u8, p, "zoneinfo" ++ std.fs.path.sep_str);
        const part = pathname_iterator.next() orelse identifier;
        if (!std.mem.eql(u8, identifier, part)) {
            const tmp_name = pathname_iterator.next() orelse "?";
            // we might need to overwrite pre-defined data with zeros:
            var name_data = std.mem.zeroes([cap_name_data]u8);
            const len: usize = if (tmp_name.len <= cap_name_data) tmp_name.len else cap_name_data;
            @memcpy(name_data[0..len], tmp_name[0..len]);
            tz.__name_data_len = len;
            tz.__name_data = name_data;
        }
    }

    return tz;
}

/// Clear a TZ instance and free potentially used memory (tzFile).
pub fn deinit(tz: *Timezone) void {
    blk: switch (tz.rules) {
        .tzif => tz.rules.tzif.deinit(), // free memory allocated for the data from the tzfile
        .posixtz => break :blk,
        .utc => break :blk,
    }

    tz.__name_data = std.mem.zeroes([cap_name_data]u8);
    tz.__name_data_len = 0;
}

/// Try to obtain the system's local time zone.
///
/// Note: Windows does not use the IANA time zone database;
/// a mapping from Windows db to IANA db is prone to errors.
/// Use with caution.
pub fn tzLocal(allocator: std.mem.Allocator) TzError!Timezone {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const default_path = "/etc/localtime";
            var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const path = std.fs.realpath(default_path, &path_buffer) catch
                return TzError.TZifUnreadable;
            return try Timezone.runtimeFromTzfile(path, "", allocator);
        },
        .windows => {
            const win_name = tzwin.getTzName() catch
                return TzError.InvalidIdentifier;
            return try Timezone.fromTzdata(win_name, allocator);
        },
        else => return TzError.NotImplemented,
    }
}

pub fn format(
    tz: *const Timezone,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("Time zone, name: {c}", .{tz.name()});
}

/// Time zone identifiers must only contain alpha-numeric characters
/// as well as '+', '-', '_' and '/' (path separator).
pub fn identifierValid(idf: []const u8) bool {
    for (idf, 0..) |c, i| {
        switch (c) {
            // OK cases:
            'A'...'Z',
            'a'...'z',
            '0'...'9',
            '+',
            '-',
            '_',
            '/',
            => continue,
            // period char is special: only OK if
            // - not last char
            // - next char is not a period
            '.' => {
                if (i == idf.len - 1) return false;
                if (idf[i + 1] == '.') return false;
                continue;
            },
            else => return false,
        }
    }
    return true;
}

test "embed tzif from lib dir" {
    const tzfile = comptime_tzdb_prefix ++ "Europe/Berlin";
    const data = @embedFile(tzfile);
    var in_stream = std.io.fixedBufferStream(data);
    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();
    try std.testing.expectEqualStrings("CET", tz.transitions[0].timetype.name());
    try std.testing.expectEqualStrings("LMT", tz.timetypes[0].name());
}

test "validate name" {
    var result = identifierValid("asdf");
    try std.testing.expectEqual(true, result);
    result = identifierValid("as/df");
    try std.testing.expectEqual(true, result);
    result = identifierValid("as.df");
    try std.testing.expectEqual(true, result);

    result = identifierValid("../asdf");
    try std.testing.expectEqual(false, result);
    result = identifierValid(".");
    try std.testing.expectEqual(false, result);
    result = identifierValid("as*df");
    try std.testing.expectEqual(false, result);
    result = identifierValid("?!");
    try std.testing.expectEqual(false, result);
}
