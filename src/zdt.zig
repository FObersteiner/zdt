// Copyright © 2023 Florian Obersteiner <f.obersteiner@posteo.de>
// License: see LICENSE file in the root directory of the zdt repository.

//! datetime in Zig
// this is just a 'collector file'

pub const Datetime = @import("./Datetime.zig");
pub const Timezone = @import("./Timezone.zig");
pub const Duration = @import("./Duration.zig");

/// ZdtError combines RangeError and TzError
pub const ZdtError = @import("errors.zig").ZdtError;
pub const RangeError = @import("errors.zig").RangeError;
pub const TzError = @import("errors.zig").TzError;

pub const calendar = @import("./calendar.zig");
pub const stringIO = @import("./stringIO.zig");
const tzif = @import("./tzif.zig");

// make sure 'internal' tests are also executed:
test {
    _ = Datetime;
    _ = Timezone;
    _ = Duration;
    _ = calendar;
    _ = stringIO;
    _ = tzif;
}
