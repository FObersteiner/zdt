// Copyright © 2023-2025 Florian Obersteiner <f.obersteiner@posteo.de>
// License: see LICENSE file in the root directory of the zdt repository.

const std = @import("std");
const log = std.log.scoped(.zdt__root);

pub const Datetime = @import("./lib/Datetime.zig");
pub const Duration = @import("./lib/Duration.zig");
pub const Formats = @import("./lib/Formats.zig");
pub const Timezone = @import("./lib/Timezone.zig");
pub const UTCoffset = @import("./lib/UTCoffset.zig");

pub const ZdtError = @import("./lib/errors.zig").ZdtError;

// make sure 'internal' tests are also executed:
const calendar = @import("./lib/calendar.zig");
const string = @import("./lib/string.zig");
const tzif = @import("./lib/tzif.zig");

test {
    _ = Datetime;
    _ = Formats;
    _ = Timezone;
    _ = Duration;
    _ = calendar;
    _ = string;
    _ = tzif;
}
