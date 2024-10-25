//! an offset relative to UTC

const std = @import("std");

const UTCoffset = @This();
const cap_name_data: usize = 32;

/// offset from UTC should be in range -25h to +26h as specified by
/// RFC8536, sect. 3.2, TZif data block.
pub const range = [2]i32{ -89999, 93599 };

/// seconds East of Greenwich
seconds_east: i32 = 0,

/// DST indicator - can only be determined if the UTC offset is derived
/// from a tz rule for given datetime.
is_dst: bool = false,

/// DST fold position; 0 = early side, 1 = late side
dst_fold: ?u1 = null,

__name_data: [cap_name_data]u8 = std.mem.zeroes([cap_name_data]u8),
__name_str_len: usize = 0,

__abbrev_data: [6:0]u8 = [6:0]u8{ 0, 0, 0, 0, 0, 0 },
__transition_index: i32 = -1, // TZif transitions index; < 0 means invalid

/// UTC is constant. Presumably.
pub const UTC = UTCoffset{
    .seconds_east = 0,
    .__abbrev_data = [6:0]u8{ 'Z', 0, 0, 0, 0, 0 },
    .__name_data_len = 3,
    .__name_data = [3]u8{ 'U', 'T', 'C' } ++ std.mem.zeroes([cap_name_data - 3]u8),
};
