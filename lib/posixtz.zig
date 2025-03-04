const std = @import("std");
const cal = @import("calendar.zig");
const log = std.log.scoped(.zdt__posixtz);

/// POSIX TZ
pub const Tz = struct {
    pub fn deinit(px: *Tz) void {
        _ = px;
    }
};
