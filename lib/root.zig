// Copyright © 2023-2025 Florian Obersteiner <f.obersteiner@posteo.de>
// License: see LICENSE file in the root directory of the zdt repository.

const std = @import("std");
const log = std.log.scoped(.zdt__root);

pub const Datetime = @import("Datetime.zig");
pub const Duration = @import("Duration.zig");
pub const Formats = @import("Formats.zig");
pub const Timezone = @import("Timezone.zig");
pub const UTCoffset = @import("UTCoffset.zig");

pub const ZdtError = @import("errors.zig").ZdtError;

// make sure 'internal' tests are also executed:
const calendar = @import("calendar.zig");
const psx = @import("posixtz.zig");
const str = @import("string.zig");
const tzif = @import("tzif.zig");

test {
    _ = Datetime;
    _ = Formats;
    _ = Timezone;
    _ = Duration;
    _ = calendar;
    _ = psx;
    _ = str;
    _ = tzif;
}
