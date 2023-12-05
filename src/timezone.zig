const std = @import("std");
const posix = @import("posix.zig");

pub const TzError = error{
    AllRulesUndefined,
    InvalidOffset,
};

/// Time zone
pub const Tz = struct {
    name: []const u8 = "",
    tzFile: ?std.tz.Tz = null, // a IANA db file with transition rules etc.
    posixRule: ?posix.PosixTZ = null, // if we have not tzfile, we can use a POSIX TZ
    // if neither a tzfile nor a POSIX rule is defined, we can still make a datetime
    // with only an offset from UTC
    offsetOnly: ?i32 = null,

    const tz_basepath = "/usr/share/zoneinfo/"; // TODO : revise

    fn clear(self: *Tz) void {
        self.tzFile = null;
        self.name = "";
        self.posixRule = null;
        self.offsetOnly = null;
    }

    /// Load a TZif file. Also sets the POSIX rule from TZif footer.
    pub fn load_tzfile(self: *Tz, idendifier: []const u8, allocator: std.mem.Allocator) !void {
        self.clear();
        if (std.mem.eql(u8, idendifier, "UTC")) { // make a shortcut for UTC
            self.name = idendifier;
            self.offsetOnly = 0;
            return;
        }
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const p = try std.fmt.bufPrint(&path_buffer, "{s}{s}", .{ tz_basepath, idendifier });
        const path = try std.fs.realpath(p, &path_buffer);
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();
        const tz = try std.tz.Tz.parse(allocator, file.reader());
        // ensure that there is a footer. requires v2+ TZif files.
        const footer = tz.footer orelse return error.BadVersion;
        const psx = try posix.parsePosixTZ(footer);
        self.name = idendifier;
        self.tzFile = tz;
        self.posixRule = psx;
    }

    pub fn load_posix(self: *Tz, posix_tz: []const u8) !void {
        self.clear();
        const psx = try posix.parsePosixTZ(posix_tz);
        self.name = posix_tz;
        self.posixRule = psx;
    }

    pub fn load_offset(self: *Tz, offset_sec_East: i32) !void {
        self.clear();
        self.offsetOnly = offset_sec_East;
    }

    /// Determine the offset from Unix time for a given Unix time in seconds
    pub fn offset_from_unix(self: Tz, unixtime: i48) TzError!TzUTCoffset {
        var result = TzUTCoffset{};
        if (self.tzFile != null) {
            // std.debug.print("\ntry tzfile", .{});
            const idx = find_le_transition(self.tzFile.?.transitions, unixtime);
            if (idx != null) {
                const tt = self.tzFile.?.transitions[idx.?].timetype;
                result.is_dst = tt.isDst();
                result.offset_seconds = tt.offset;
                result.abbreviation = &tt.name_data;
                return result;
            }
        }
        if (self.posixRule != null) {
            // std.debug.print("\ntry posixRule", .{});
            const off = self.posixRule.?.offset(unixtime);
            result.is_dst = off.is_daylight_saving_time;
            result.offset_seconds = off.offset;
            result.abbreviation = off.designation;
            return result;
        }
        if (self.offsetOnly != null) {
            // std.debug.print("\ntry offsetOnly", .{});
            result.offset_seconds = self.offsetOnly.?;
            result.abbreviation = self.name;
            return result;
        }
        return TzError.AllRulesUndefined;
    }
};

// a fully qualified UTC offset: with offset seconds, a time zone abbreviation and a DST indicator
pub const TzUTCoffset = struct {
    offset_seconds: i32 = 0,
    abbreviation: []const u8 = "",
    is_dst: bool = false,

    pub fn to_offset_string(self: TzUTCoffset) ![6]u8 {
        const this: u19 = if (self.offset_seconds < 0) @intCast(self.offset_seconds * -1) else @intCast(self.offset_seconds);
        const sign = if (self.offset_seconds < 0) "-" else "+";
        const minutes = @divFloor(this, 60);
        const h = @divFloor(minutes, 60);
        const m = @mod(minutes, 60);
        var b: [6]u8 = undefined;
        _ = try std.fmt.bufPrint(&b, "{s}{d:0>2}:{d:0>2}", .{ sign, h, m });
        return b;
    }

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
