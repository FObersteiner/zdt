//! an offset relative to UTC

const std = @import("std");

const Timezone = @import("./Timezone.zig");
const TzError = @import("./errors.zig").TzError;
const tzif = @import("./tzif.zig");

const UTCoffset = @This();

const cap_name_data: usize = 32;

/// offset from UTC should be in range -25h to +26h as specified by
/// RFC8536, sect. 3.2, TZif data block.
pub const offset_range = [2]i32{ -89999, 93599 };

/// seconds East of Greenwich
seconds_east: i32 = 0,

/// DST indicator - can only be determined if the UTC offset is derived
/// from a tz rule for given datetime.
is_dst: bool = false,

// TODO : might not need both name data AND abbreviation data
__name_data: [cap_name_data]u8 = std.mem.zeroes([cap_name_data]u8),
__name_str_len: usize = 0,

__abbrev_data: [6:0]u8 = [6:0]u8{ 0, 0, 0, 0, 0, 0 },
__transition_index: i32 = -1, // TZif transitions index; < 0 means invalid

/// UTC is constant. Presumably.
pub const UTC = UTCoffset{
    .seconds_east = 0,
    .__abbrev_data = [6:0]u8{ 'Z', 0, 0, 0, 0, 0 },
    .__name_str_len = 3,
    .__name_data = [3]u8{ 'U', 'T', 'C' } ++ std.mem.zeroes([cap_name_data - 3]u8),
};

/// Abbreviation such as "CET" for Central European Time in Europe/Berlin, winter.
///
/// Note that multiple time zones can share the same abbreviated name and are
/// therefore ambiguous.
pub fn abbreviation(offset: *const UTCoffset) []const u8 {
    return std.mem.sliceTo(&offset.__abbrev_data, 0);
}

/// Name of the origin time zone of a UTC offset.
pub fn originName(offset: *const UTCoffset) []const u8 {
    return std.mem.sliceTo(&offset.__name_data, 0);
}

pub fn fromSeconds(offset_sec_East: i32, identifier: []const u8) TzError!UTCoffset {
    if (offset_sec_East < offset_range[0] or offset_sec_East > offset_range[1]) {
        return TzError.InvalidOffset;
    }
    if (std.mem.eql(u8, identifier, "UTC")) {
        return UTC;
    }

    var name_data = std.mem.zeroes([cap_name_data]u8);
    const len: usize = if (identifier.len <= cap_name_data) identifier.len else cap_name_data;
    @memcpy(name_data[0..len], identifier[0..len]);

    return .{
        .seconds_east = offset_sec_East,
        .__name_data = name_data,
        .__name_data_len = len,
    };
}

/// Get the UTC offset at a certain Unix time. Creates a new UTCoffset.
/// Priority for offset determination is tzfile > POSIX TZ > fixed offset.
/// tzFile and tzPosix set tzOffset if possible.
pub fn atUnixtime(tz: *const Timezone, unixtime: i64) TzError!UTCoffset {
    switch (tz.rules) {
        .tzif => {
            const idx = findTransition(tz.rules.tzif.transitions, unixtime);
            const timet = switch (idx) {
                -1 => if (tz.rules.tzif.timetypes.len == 1) // UTC offset time zones...
                    tz.rules.tzif.timetypes[0]
                else
                    return TzError.InvalidTz,
                // Unix time exceeds defined range of transitions => could use POSIX rule here as well
                -2 => tz.rules.tzif.transitions[tz.rules.tzif.transitions.len - 1].timetype.*,
                // Unix time precedes defined range of transitions => use first entry in timetypes (should be LMT)
                -3 => tz.rules.tzif.timetypes[0],
                else => tz.rules.tzif.transitions[@intCast(idx)].timetype.*,
            };

            return .{
                .seconds_east = @intCast(timet.offset),
                .is_dst = timet.isDst(),
                .__abbrev_data = timet.name_data,
                .__transition_index = idx,
            };
        },
        .posixtz => {
            return TzError.NotImplemented;
        },
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
