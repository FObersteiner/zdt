//! datetime in Zig

// this is just a 'collector file'
pub const datetime = @import("./datetime.zig");
pub const duration = @import("./duration.zig");
pub const calendar = @import("./calendar.zig");
pub const tz = @import("./timezone.zig");
pub const str = @import("./stringIO.zig");

test {
    _ = datetime;
    _ = duration;
    _ = calendar;
    _ = tz;
    _ = str;
}
