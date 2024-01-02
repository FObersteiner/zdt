const std = @import("std");
const datetime = @import("datetime.zig");

// TODO : make this a "struct-file" ?

pub const TzError = error{
    AllTZRulesUndefined,
    InvalidOffset,
    BadTZifVersion,
    InvalidTz,
    AmbiguousDatetime,
    NonexistentDatetime,
    TzAlreadyDefined,
    TzUndefined,
    CompareNaiveAware,
    NotImplemented,
};

/// Where to look for IANA tz database files
pub const tz_basepath = "/usr/share/zoneinfo/"; // TODO : revise; this is platform-specific

/// offset from UTC should be in range -25h to +26h as specified by
/// RFC8536, sect. 3.2, TZif data block.
pub const UT_off_range = [2]i20{ -89999, 93599 };

/// Convenience constant for UTC
pub const UTC = TZ{
    .name = "UTC",
    .abbreviation = [6:0]u8{ 'Z', 0, 0xAA, 0xAA, 0xAA, 0xAA },
    .is_dst = false,
    .tzOffset = UToffset{ .seconds_east = 0 },
};

/// Convenience method to make a time zone from a IANA db file. The caller
/// must make sure to de-allocate memory used for storing the TZif file's content
/// by calling the deinit method of the returned TZ instance.
pub fn fromTzfile(idendifier: []const u8, allocator: std.mem.Allocator) !TZ {
    var tzinfo = TZ{};
    try tzinfo.loadTzfile(idendifier, allocator);
    return tzinfo;
}

/// Convenience method to make a time zone from an offset from UTC.
pub fn fromOffset(offset_sec_East: i32, name: []const u8) TzError!TZ {
    if (offset_sec_East < UT_off_range[0] or offset_sec_East > UT_off_range[1]) {
        return TzError.InvalidOffset;
    }
    var tzinfo = TZ{};
    try tzinfo.loadOffset(@intCast(offset_sec_East), name);
    if (std.mem.eql(u8, name, "UTC")) {
        tzinfo.abbreviation = [6:0]u8{ 'Z', 0x00, 0xAA, 0xAA, 0xAA, 0xAA };
    }
    return tzinfo;
}

/// UT offset as seconds East of Greenwich
pub const UToffset = struct {
    seconds_east: i20 = 0,
    __transition_index: i32 = -1, // TZif transistions index. -1 means invalid.
};

/// Time zone container for:
/// - a fixed offset from UTC (not a time zone in a geographical sense)
/// - a tzfile, meaning a IANA database time zone file
/// - (not impolemented yet) a POSIX TZ rule such as "EST5EDT,M3.2.0/4:00,M11.1.0/3:00"
pub const TZ = struct {
    name: []const u8 = "", // name can be multiple things, depending on input
    abbreviation: [6:0]u8 = [6:0]u8{ 0x00, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA }, // only makes sense in combination with a datetime
    is_dst: bool = undefined,
    // time zone rule sources:
    tzFile: ?std.tz.Tz = null, // a IANA db file with transitions list etc.
    tzPosix: ?bool = null, // TODO : implement // POSIX TZ rule
    tzOffset: ?UToffset = null,

    /// Clear a TZ instance and free potentially used memory
    pub fn deinit(self: *TZ) void {
        self.name = "";
        self.abbreviation = [6:0]u8{ 0x00, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA };
        if (self.tzFile != null) {
            self.tzFile.?.deinit(); // free memory allocated for the data from the tzfile
            self.tzFile = null;
        }
        self.tzPosix = null;
        self.tzOffset = null;
    }

    /// Load a fixed offset. Clears POSIX TZ and tzfile fields.
    pub fn loadOffset(self: *TZ, offset_sec_East: i32, name: []const u8) TzError!void {
        if (offset_sec_East < UT_off_range[0] or offset_sec_East > UT_off_range[1]) {
            return TzError.InvalidOffset;
        }
        self.deinit();
        self.name = name;
        self.tzOffset = UToffset{ .seconds_east = @intCast(offset_sec_East) };
    }

    /// Load a POSIX TZ rule. Clears fixed offset and tzfile fields.
    pub fn loadPosix(self: *TZ, posix_string: []const u8) TzError!void {
        // self.deinit();
        _ = self;
        _ = posix_string;
        return TzError.NotImplemented; // TODO : handle posix tz
    }

    /// Load a TZif file. Clears fixed offset and POSIX TZ fields.
    /// The caller must make sure to de-allocate memory used for storing the TZif file's content
    /// by calling the deinit method of the returned TZ instance.
    pub fn loadTzfile(self: *TZ, idendifier: []const u8, allocator: std.mem.Allocator) !void {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const p = try std.fmt.bufPrint(&path_buffer, "{s}{s}", .{ tz_basepath, idendifier });
        const path = try std.fs.realpath(p, &path_buffer);
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();
        const tz = try std.tz.Tz.parse(allocator, file.reader());
        // ensure that there is a footer. requires v2+ TZif files.
        const footer = tz.footer orelse return TzError.BadTZifVersion;
        _ = footer; // TODO : handle posix tz

        self.deinit();
        self.name = idendifier;
        self.tzFile = tz;
    }

    /// Localize a tzinfo to a certain Unix time. Creates a new TZ.
    /// Priority for offset determination is tzfile > POSIX TZ > fixed offset.
    /// tzFile and tzPosix set tzOffset if possible.
    pub fn atUnixtime(self: TZ, unixtime: i48) TzError!TZ {
        if (self.tzFile == null and self.tzPosix == null and self.tzOffset == null) {
            return TzError.AllTZRulesUndefined;
        }

        if (self.tzFile != null) {
            const idx = findTransition(self.tzFile.?.transitions, unixtime);
            const timet = switch (idx) {
                -1 => if (self.tzFile.?.timetypes.len == 1) // UTC offset time zones...
                    self.tzFile.?.timetypes[0]
                else
                    return TzError.InvalidTz,
                // Unix time exceedes defined range of transitions => could use POSIX rule here as well
                -2 => self.tzFile.?.transitions[self.tzFile.?.transitions.len - 1].timetype.*,
                // Unix time precedes defined range of transitions => use first entry in timetypes (should be LMT)
                -3 => self.tzFile.?.timetypes[0],
                else => self.tzFile.?.transitions[@intCast(idx)].timetype.*,
            };

            return .{
                .name = self.name,
                .abbreviation = timet.name_data,
                .is_dst = timet.isDst(),
                .tzOffset = UToffset{ .seconds_east = @intCast(timet.offset), .__transition_index = idx },
                .tzPosix = self.tzPosix,
                .tzFile = self.tzFile,
            };
        }

        if (self.tzPosix != null) {
            return TzError.NotImplemented; // TODO : handle posix tz
        }

        // if we already have an offset here but no tzFile or tzPosix, there's nothing
        // more we can do.
        if (self.tzOffset != null) {
            return self;
        }

        return TzError.AllTZRulesUndefined;
    }

    pub fn format(
        self: TZ,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Time zone, name: {s}, abbreviation: {s}", .{
            self.name,
            self.abbreviation,
        });
        if (self.tzOffset != null) {
            try writer.print(
                ", offset from UTC: {d} s, daylight saving time? {}",
                .{ self.tzOffset.?.seconds_east, self.is_dst },
            );
        }
    }
};

/// Get the index of the UTC offset transion equal to or less than the given target.
/// Invalid value indicators:
/// -1 : transition array has len zero
/// -2 : target is larger than last transition element
/// -3 : target is smaller than first transition element
fn findTransition(array: []const std.tz.Transition, target: i64) i32 {
    if (array.len == 0) return -1;
    // we know that 'items' is sorted, so we can check first and last indices.
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
