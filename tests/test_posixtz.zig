//! test posix tz

const std = @import("std");
const testing = std.testing;

const log = std.log.scoped(.test_posixtz);

const _ = @import("zdt"); // dummy import so we can import from ../lib
const psx = @import("../lib/posixtz.zig");

test "wtf" {
    log.warn("???? {any}", .{psx.Tz});
}
