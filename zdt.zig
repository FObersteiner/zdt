// Copyright © 2023-2024 Florian Obersteiner <f.obersteiner@posteo.de>
// License: see LICENSE file in the root directory of the zdt repository.

const std = @import("std");
const log = std.log.scoped(.zdt__root);

pub const Datetime = @import("./lib/Datetime.zig");
pub const Timezone = @import("./lib/Timezone.zig");
pub const Duration = @import("./lib/Duration.zig");

pub const RangeError = @import("./lib/errors.zig").RangeError;
pub const TzError = @import("./lib/errors.zig").TzError;
pub const WinTzError = @import("./lib/errors.zig").WinTzError;
pub const ZdtError = @import("./lib/errors.zig").ZdtError;

pub const calendar = @import("./lib/calendar.zig");

const stringIO = @import("./lib/stringIO.zig");
const tzif = @import("./lib/tzif.zig");

// available as zdt.[method] :
pub const formatToString = @import("./lib/stringIO.zig").formatToString;
pub const parseToDatetime = @import("./lib/stringIO.zig").parseToDatetime;
pub const parseISO8601 = @import("./lib/stringIO.zig").parseISO8601;

// make sure 'internal' tests are also executed:
test {
    _ = Datetime;
    _ = Timezone;
    _ = Duration;
    _ = calendar;
    _ = stringIO;
    _ = tzif;
}
