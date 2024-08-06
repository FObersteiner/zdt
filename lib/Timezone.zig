//! a set of rules to describe date and time somewhere on earth, relative to universal time (UTC)

const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.zdt__Timezone);

const Datetime = @import("./Datetime.zig");
const TzError = @import("./errors.zig").TzError;
const tzif = @import("./tzif.zig");
const tzwin = @import("./windows/windows_tz.zig");
const tzvers = @import("./tzdb_version.zig");

const Timezone = @This();

// longest tz name is 'America/Argentina/ComodRivadavia' --> 32 ASCII chars
const cap_name_data: usize = 32;
__name_data: [cap_name_data]u8 = std.mem.zeroes([cap_name_data]u8),
__name_data_len: usize = 0,

// time zone rule sources:
tzFile: ?tzif.Tz = null, // a IANA db file with transitions list etc.
tzPosix: ?bool = null, // TODO : implement // POSIX TZ string with rule
tzOffset: ?UTCoffset = null,

/// auto-generated string of the current eggert/tz version
pub const tzdb_version = tzvers.tzdb_version;

/// auto-generated prefix / path of the current eggert/tz database, as shipped with zdt
// anonymous import; see build.zig
pub const tzdb_prefix = @import("tzdb_prefix").tzdb_prefix;

/// Where to comptime-load IANA tz database files from
const comptime_tzdb_prefix = "./tzdata/zoneinfo/"; // IANA db as provided by the library

/// offset from UTC should be in range -25h to +26h as specified by
/// RFC8536, sect. 3.2, TZif data block.
pub const UTC_off_range = [2]i32{ -89999, 93599 };

/// offset from UTC, in seconds East of Greenwich
pub const UTCoffset = struct {
    seconds_east: i32 = 0,
    is_dst: bool = false,
    __abbrev_data: [6:0]u8 = [6:0]u8{ 0, 0, 0, 0, 0, 0 },
    __transition_index: i32 = -1, // TZif transitions index. -1 means invalid
};

/// Create the UTC "time zone"
pub const UTC = Timezone{
    .tzOffset = UTCoffset{ .seconds_east = 0, .__abbrev_data = [6:0]u8{ 90, 0, 0, 0, 0, 0 } },
    .__name_data_len = 3,
    .__name_data = [3]u8{ 85, 84, 67 } ++ std.mem.zeroes([cap_name_data - 3]u8),
};

/// A time zone's name (identifier)
pub fn name(tz: *Timezone) []const u8 {
    // 'tz' must be a pointer to TZ, otherwise returned slice would point to an out-of-scope
    // copy of the TZ instance. See also <https://ziggit.dev/t/pointers-to-temporary-memory/>
    return tz.__name_data[0..tz.__name_data_len];
}

/// Time zone abbreviation, such as "CET" for Central European Time in Europe/Berlin, winter.
/// The tzOffset must be defined; otherwise, it is not possible to distinguish e.g. CET and CEST.
pub fn abbreviation(tz: *Timezone) []const u8 {
    if (tz.tzOffset == null) return "";
    return std.mem.sliceTo(tz.tzOffset.?.__abbrev_data[0..], 0);
}

/// Make a time zone from a IANA tz database TZif file. The identifier must be comptime-known.
/// The caller must make sure to de-allocate memory used for storing the TZif file's content
/// by calling the deinit method of the returned TZ instance.
pub fn fromTzfile(comptime identifier: []const u8, allocator: std.mem.Allocator) !Timezone {
    if (!identifierValid(identifier)) return TzError.InvalidIdentifier;
    const data = @embedFile(comptime_tzdb_prefix ++ identifier);
    var in_stream = std.io.fixedBufferStream(data);
    const tzif_tz = try tzif.Tz.parse(allocator, in_stream.reader());
    // ensure that there is a footer: requires v2+ TZif files.
    _ = tzif_tz.footer orelse return TzError.BadTZifVersion; // TODO : handle posix tz

    var tz = Timezone{ .tzFile = tzif_tz };
    tz.__name_data_len = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
    @memcpy(tz.__name_data[0..tz.__name_data_len], identifier[0..tz.__name_data_len]);

    return tz;
}

/// Same as fromTzfile but for runtime-known tz identifiers.
pub fn runtimeFromTzfile(identifier: []const u8, db_path: []const u8, allocator: std.mem.Allocator) !Timezone {
    if (!identifierValid(identifier)) return TzError.InvalidIdentifier;
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&path_buffer);
    const fb_alloc = fba.allocator();
    const p = try std.fs.path.join(fb_alloc, &[_][]const u8{ db_path, identifier });

    const file = try std.fs.openFileAbsolute(p, .{});
    defer file.close();
    const tzif_tz = try tzif.Tz.parse(allocator, file.reader());
    // ensure that there is a footer: requires v2+ TZif files.
    _ = tzif_tz.footer orelse return TzError.BadTZifVersion; // TODO : handle posix tz

    var tz = Timezone{ .tzFile = tzif_tz };
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

/// Make a time zone from an offset from UTC.
pub fn fromOffset(offset_sec_East: i32, identifier: []const u8) TzError!Timezone {
    if (offset_sec_East < UTC_off_range[0] or offset_sec_East > UTC_off_range[1]) {
        return TzError.InvalidOffset;
    }
    if (std.mem.eql(u8, identifier, "UTC")) {
        return UTC;
    }

    var name_data = std.mem.zeroes([cap_name_data]u8);
    const len: usize = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
    @memcpy(name_data[0..len], identifier[0..len]);

    return .{
        .tzOffset = .{ .seconds_east = @intCast(offset_sec_East) },
        .__name_data = name_data,
        .__name_data_len = len,
    };
}

/// Clear a TZ instance and free potentially used memory (tzFile)
pub fn deinit(tz: *Timezone) void {
    if (tz.tzFile != null) {
        tz.tzFile.?.deinit(); // free memory allocated for the data from the tzfile
        tz.tzFile = null;
    }
    tz.tzPosix = null;
    tz.tzOffset = null;
    tz.__name_data = std.mem.zeroes([cap_name_data]u8);
    tz.__name_data_len = 0;
}

/// Try to obtain the system's local time zone
///
/// Note, Windows OS: Windows does not use the IANA time zone database;
/// a mapping from Windows db to IANA db is prone to errors.
/// Use with caution.
pub fn tzLocal(allocator: std.mem.Allocator) !Timezone {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const default_path = "/etc/localtime";
            var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const path = try std.fs.realpath(default_path, &path_buffer);
            return try Timezone.runtimeFromTzfile(path, "", allocator);
        },
        .windows => {
            const win_name = try tzwin.getTzName();
            return try Timezone.runtimeFromTzfile(win_name, tzdb_prefix, allocator);
        },
        else => return TzError.NotImplemented,
    }
}

/// Get the UTC offset at a certain Unix time. Creates a new UTCoffset.
/// Priority for offset determination is tzfile > POSIX TZ > fixed offset.
/// tzFile and tzPosix set tzOffset if possible.
pub fn atUnixtime(tz: Timezone, unixtime: i64) TzError!UTCoffset {
    if (tz.tzFile == null and tz.tzPosix == null and tz.tzOffset == null) {
        return TzError.AllTZRulesUndefined;
    }

    if (tz.tzFile != null) {
        const idx = findTransition(tz.tzFile.?.transitions, unixtime);
        const timet = switch (idx) {
            -1 => if (tz.tzFile.?.timetypes.len == 1) // UTC offset time zones...
                tz.tzFile.?.timetypes[0]
            else
                return TzError.InvalidTz,
            // Unix time exceeds defined range of transitions => could use POSIX rule here as well
            -2 => tz.tzFile.?.transitions[tz.tzFile.?.transitions.len - 1].timetype.*,
            // Unix time precedes defined range of transitions => use first entry in timetypes (should be LMT)
            -3 => tz.tzFile.?.timetypes[0],
            else => tz.tzFile.?.transitions[@intCast(idx)].timetype.*,
        };

        return .{
            .seconds_east = @intCast(timet.offset),
            .is_dst = timet.isDst(),
            .__abbrev_data = timet.name_data,
            .__transition_index = idx,
        };
    }

    if (tz.tzPosix != null) {
        return TzError.NotImplemented; // TODO : handle posix tz
    }

    // if we already have an offset here but no tzFile or tzPosix, there's nothing more we can do.
    if (tz.tzOffset) |offset| {
        return offset;
    }

    return TzError.AllTZRulesUndefined;
}

pub fn format(
    tz: Timezone,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var _tz = tz; // need a variable copy because we have pointer methods
    try writer.print("Time zone, name: {c}", .{
        _tz.name(),
    });
    if (_tz.tzOffset) |offset| {
        try writer.print(
            ", abbreviation: {c}, offset from UTC: {d} s, daylight saving time? {}",
            .{
                _tz.abbreviation(),
                offset.seconds_east,
                offset.is_dst,
            },
        );
    }
}

/// Get the index of the UTC offset transition equal to or less than the given target.
/// Invalid value indicators:
/// -1 : transition array has len zero
/// -2 : target is larger than last transition element
/// -3 : target is smaller than first transition element
fn findTransition(array: []const tzif.Transition, target: i64) i32 {
    if (array.len == 0) return -1;
    // we know that transitions in 'array' are sorted, so we can check first and last indices.
    // if 'target' is out of range, caller should return to use tz.timetype[0]
    // or tz.timetype[-1] resp.
    if (target > array[array.len - 1].ts) return -2;
    if (target < array[0].ts) return -3;

    // now do a binary search:
    var left: usize = 0;
    var right: usize = array.len - 1;
    while (left <= right) {
        const middle = left + @divFloor(right - left, 2);
        if (array[middle].ts < target) {
            left = middle + 1;
        } else if (array[middle].ts > target) {
            right = middle - 1;
        } else {
            return @as(i32, @intCast(middle));
        }
    }
    return @as(i32, @intCast(left - 1));
}

/// time zone identifiers must only contain alpha-numeric characters
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
