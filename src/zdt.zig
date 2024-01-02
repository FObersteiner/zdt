// Copyright © 2023 Florian Obersteiner <f.obersteiner@posteo.de>
// License: see LICENSE file in the root directory of the zdt repository.

//! datetime in Zig
// this is just a 'collector file'

pub const datetime = @import("./datetime.zig");
pub const Duration = @import("./Duration.zig");
pub const calendar = @import("./calendar.zig");
pub const timezone = @import("./timezone.zig");
pub const stringIO = @import("./stringIO.zig");

// make sure 'internal' tests are also executed:
test {
    _ = datetime;
    _ = Duration;
    _ = calendar;
    _ = timezone;
    _ = stringIO;
}
