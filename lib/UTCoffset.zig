//! an offset relative to UTC

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.zdt__UTCoffset);

const Timezone = @import("./Timezone.zig");
const TzError = @import("./errors.zig").TzError;
const tzif = @import("./tzif.zig");
const psx = @import("./posixtz.zig");

const UTCoffset = @This();

const cap_designation_data: usize = 6;

/// Offset from UTC should be in range `(-25h ... +26h)` as specified by
/// RFC9636, sect. 3.2, TZif data block.
pub const offset_range = [2]i32{ -89999, 93599 };

/// Seconds East of Greenwich.
seconds_east: i32 = 0,

/// DST indicator - can only be determined if the UTC offset is derived
/// from a tz rule (POSIX, TZif) for given datetime.
is_dst: bool = false,

// 'internal'; data for the offset designation.
__designation_data: [6:0]u8 = [6:0]u8{ 0, 0, 0, 0, 0, 0 },

// 'internal'; TZif transitions index; < 0 means invalid.
__transition_index: i32 = -1,

/// UTC is constant. Presumably.
pub const UTC = UTCoffset{
    .__designation_data = [6:0]u8{ 'U', 'T', 'C', 0, 0, 0 },
};

/// Designation / abbreviated time zone name such as "CET" for
/// Central European Time in Europe/Berlin, winter.
///
/// Note that multiple time zones can share the same abbreviated name;
/// the abbreviations are therefore ambiguous.
pub fn designation(offset: *const UTCoffset) []const u8 {
    return std.mem.sliceTo(&offset.__designation_data, 0);
}

/// Make a UTC offset from a given number of seconds East of Greenwich.
pub fn fromSeconds(offset_sec_East: i32, name: []const u8, is_dst: bool) TzError!UTCoffset {
    if (offset_sec_East < offset_range[0] or offset_sec_East > offset_range[1]) {
        return TzError.InvalidOffset;
    }
    if (std.mem.eql(u8, name, "UTC")) {
        return UTC;
    }

    var name_data = std.mem.zeroes([cap_designation_data:0]u8);
    const len: usize = if (name.len <= cap_designation_data) name.len else cap_designation_data;
    std.mem.copyForwards(u8, name_data[0..len], name[0..len]);

    return .{
        .seconds_east = offset_sec_East,
        .__designation_data = name_data,
        .is_dst = is_dst,
    };
}

/// Given time zone rules, get the UTC offset at a certain Unix time.
pub fn atUnixtime(tz: *const Timezone, unixtime: i64) TzError!UTCoffset {
    switch (tz.rules) {
        .tzif => {
            // If the tz only has one timetype (offset spec.): use this.
            // Otherwise try to determine it from the defined transitions.
            const idx = if (tz.rules.tzif.timetypes.len == 1) -1 else findTransitionIdx(&tz.rules.tzif.transitions, unixtime);

            const timet = switch (idx) {
                -1 => blk: {
                    assert(tz.rules.tzif.timetypes.len == 1);
                    break :blk tz.rules.tzif.timetypes[0];
                },

                // Unix time exceeds defined range of transitions => use POSIX from tzif footer
                -2 => blk: {
                    // check the POSIX TZ from the footer.
                    const psxtz = psx.parsePosixTzString(tz.rules.tzif.footer.?) catch return TzError.InvalidPosixTz;
                    // If it has DST, make a UTC offset directly
                    if (psxtz.dst_offset) |_| return psxtz.utcOffsetAt(unixtime);
                    // ...otherwise use existing timetype
                    break :blk tz.rules.tzif.timetypes[tz.rules.tzif.transitions[tz.rules.tzif.transitions.len - 1].timetype_idx];
                },

                // Unix time precedes defined range of transitions => use first entry in timetypes (likely a LMT)
                -3 => tz.rules.tzif.timetypes[0],

                else => tz.rules.tzif.timetypes[tz.rules.tzif.transitions[@intCast(idx)].timetype_idx],
            };

            return .{
                .seconds_east = @intCast(timet.offset),
                .is_dst = timet.isDst(),
                .__designation_data = timet.name_data,
                .__transition_index = idx,
            };
        },
        .tzif_fixedsize => { // same as .tzif but for the fixed-size structure
            const idx: i32 = if (tz.rules.tzif_fixedsize.n_timetypes == 1)
                -1
            else
                findTransitionIdx(
                    &tz.rules.tzif_fixedsize.__transitions_data[0..tz.rules.tzif_fixedsize.n_transitions],
                    unixtime,
                );

            const timet = switch (idx) {
                -1 => blk: {
                    assert(tz.rules.tzif_fixedsize.n_timetypes == 1);
                    break :blk tz.rules.tzif_fixedsize.__timetypes_data[0];
                },

                -2 => blk: {
                    const psxtz = psx.parsePosixTzString(std.mem.sliceTo(
                        tz.rules.tzif_fixedsize.__footer_data[0..],
                        '\n',
                    )) catch
                        return TzError.InvalidPosixTz;
                    if (psxtz.dst_offset) |_| return psxtz.utcOffsetAt(unixtime);
                    break :blk tz.rules.tzif_fixedsize.__timetypes_data[
                        tz.rules.tzif_fixedsize.__transitions_data[
                            tz.rules.tzif_fixedsize.n_transitions - 1
                        ].timetype_idx
                    ];
                },

                -3 => tz.rules.tzif_fixedsize.__timetypes_data[0],

                else => tz.rules.tzif_fixedsize.__timetypes_data[
                    tz.rules.tzif_fixedsize.__transitions_data[
                        @intCast(idx)
                    ].timetype_idx
                ],
            };

            return .{
                .seconds_east = @intCast(timet.offset),
                .is_dst = timet.isDst(),
                .__designation_data = timet.name_data,
                .__transition_index = idx,
            };
        },
        .posixtz => return tz.rules.posixtz.utcOffsetAt(unixtime),
        .utc => return UTC,
    }
}

/// Custom formatter for the Offset struct.
/// `fmt` is ignored.
/// `options` can be used to modify precision.
pub fn format(
    offset: UTCoffset,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) anyerror!void {
    _ = fmt;
    const off = offset.seconds_east;
    const absoff: u32 = if (off < 0) @intCast(off * -1) else @intCast(off);
    const sign = if (off < 0) "-" else "+";
    const hours = absoff / 3600;
    const minutes = (absoff % 3600) / 60;
    const seconds = (absoff % 3600) % 60;

    // precision: 0 - hours, 1 - hours:minutes, 2 - hours:minutes:seconds
    const precision = if (options.precision) |p| p else 1;

    if (options.fill != 0) {
        try writer.print("{s}{d:0>2}", .{ sign, hours });
        if (precision > 0)
            try writer.print("{u}{d:0>2}", .{ options.fill, minutes });
        if (precision > 1)
            try writer.print("{u}{d:0>2}", .{ options.fill, seconds });
    } else {
        try writer.print("{s}{d:0>2}{d:0>2}", .{ sign, hours, minutes });
    }
}

/// Get the index of the UTC offset transition equal to or less than the given target.
///
/// Invalid value indicators:
/// ```
/// -1 : transition array has no elements (single offset tz)
/// -2 : target is larger than last transition element
/// -3 : target is smaller than first transition element
/// ```
fn findTransitionIdx(transitions_ptr: *const []const tzif.Transition, target: i64) i32 {
    if (transitions_ptr.*.len == 0) return -1;
    // we know that transitions in 'array' are sorted, so we can check first and last indices.
    // if 'target' is out of range, caller should fall back to using tz.timetype[0]
    // or tz.timetype[-1] resp.
    if (target > transitions_ptr.*[transitions_ptr.*.len - 1].ts) return -2;
    if (target < transitions_ptr.*[0].ts) return -3;

    // now do a binary search:
    var left: usize = 0;
    var right: usize = transitions_ptr.*.len - 1;
    while (left <= right) {
        const middle = left + @divFloor(right - left, 2);
        if (transitions_ptr.*[middle].ts < target) {
            left = middle + 1;
        } else if (transitions_ptr.*[middle].ts > target) {
            right = middle - 1;
        } else {
            return @as(i32, @intCast(middle));
        }
    }
    return @as(i32, @intCast(left - 1));
}
