/// POSIX TZ, not implemented!
pub const Tz = struct {
    // not implemented
    string: []const u8,

    pub fn deinit(px: *Tz) void {
        _ = px;
    }
};
