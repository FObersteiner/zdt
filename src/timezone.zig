const std = @import("std");
const tzif = @import("tzif.zig");
const log = std.log.scoped(.timezone);

/// Time zone
pub const Tz = struct {
    name: []const u8 = "",
    tzfile: ?std.tz.Tz = null, // a IANA db file with transition rules etc.
    posixrule: ?tzif.PosixTZ = null, // if we have not tzfile, we can use a POSIX TZ
    // if neither a tzfile nor a POSIX rule is defined, we can still make a datetime
    // with only an offset from UTC
    offsetOnly: ?i32 = null,

    const tz_basepath = "/usr/share/zoneinfo/"; // TODO : revise

    // TODO : revise tz loading
    // - allow direct loading from POSIX or offset-only

    /// Load a TZif file
    pub fn load(self: *Tz, idendifier: []const u8, allocator: std.mem.Allocator) !void {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const p = try std.fmt.bufPrint(&path_buffer, "{s}{s}", .{ tz_basepath, idendifier });
        const path = try std.fs.realpath(p, &path_buffer);
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();
        const tz = try std.tz.Tz.parse(allocator, file.reader());
        // ensure that there is a footer. requires v2+ TZif files.
        const footer = tz.footer orelse return error.BadVersion;
        const psx = try tzif.parsePosixTZ(footer);
        self.name = idendifier;
        self.tzfile = tz;
        self.posixrule = psx;
    }

    /// Determine the offset from UTC for a given Unix time in seconds
    pub fn offset_from_utc(self: Tz, unixtime: i48) TzUTCoffset {
        var result = TzUTCoffset{};
        const idx = find_le_transition(self.tzfile.?.transitions, unixtime); // TODO : handle tzfile is null
        if (idx != null) {
            const tt = self.tzfile.?.transitions[idx.?].timetype;
            result.is_dst = tt.isDst();
            result.offset_seconds = tt.offset;
            result.abbreviation = &tt.name_data;
        } else {
            // if idx is null, use the POSIX rule
        }
        return result;
    }
};

// a fully qualified UTC offset: with offset seconds, a time zone abbreviation and a DST indicator
pub const TzUTCoffset = struct {
    offset_seconds: i32 = 0,
    abbreviation: []const u8 = "",
    is_dst: bool = false,

    // TODO : pub fn format() {}
    // const minutes = @divFloor(this, 60);
    // const h = @divFloor(minutes, 60);
    // const m = @mod(minutes, 60);
    // std.debug.print("\n{s}{d:0>2}:{d:0>2}", .{ sign, h, m });

    // TODO : pub fn parse() {}
};

/// Get the index of the UTC offset transion equal or less than the given target.
/// If the target is out of range for given array of transitions, Null is returned.
fn find_le_transition(array: []const std.tz.Transition, target: i64) ?usize {
    if (array.len == 0) return null;
    // we know that 'items' is sorted, so we can check first and last indices
    // target must be greater or equal than the first element and not greater than the last
    if (array[0].ts > target or array[array.len - 1].ts < target) return null;

    // TODO : revise:
    // actually, if target is smaller than the minimum specified transition time, we want to use LMT

    var left: usize = 0;
    var right: usize = array.len - 1;
    while (left <= right) {
        const middle = @divFloor(left + right, 2);
        if (array[middle].ts < target) {
            left = middle + 1;
        } else if (array[middle].ts > target) {
            right = middle - 1;
        } else {
            return middle;
        }
    }
    return left - 1;
}
