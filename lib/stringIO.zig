//! conversion between datetime and string representation

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.zdt__stringIO);

const Datetime = @import("./Datetime.zig");
const Tz = @import("./Timezone.zig");
const unix_specific = @import("./unix/unix_mdnames.zig");
const windows_specific = @import("./windows/windows_mdnames.zig");

/// directives to create string representation of a datetime
const FormatCode = enum(u8) {
    day_name_abbr = 'a', // locale-specific
    day_name = 'A', // locale-specific
    // %w
    day = 'd',
    month_name_abbr = 'b', // locale-specific
    month_name = 'B', // locale-specific
    month = 'm',
    // %y ?
    year = 'Y',
    hour = 'H',
    // %I ?
    // %p ? // locale-specific
    min = 'M',
    sec = 'S',
    nanos = 'f',
    offset = 'z',
    tz_abbrev = 'Z',
    doy = 'j',
    // %U - weeknum, sun = 00
    // %W - weeknum, mon = 00
    // %G - ISO year 0000
    // %u - ISO weekday, mon = 1
    // %V - ISO weeknum, mon = 01 (contains Jan 4)
    isofmt = 'T', // %T - ISO8601
    // %c // locale-specific
    // %x // locale-specific
    // %X // locale-specific
    percent_lit = '%',

    /// create string representation of datetime fields and properties
    pub fn formatToString(
        self: FormatCode,
        writer: anytype,
        dt: Datetime,
    ) !void {
        switch (self) {
            .month => try writer.print("{d:0>2}", .{dt.month}),
            .year => try writer.print("{d:0>4}", .{dt.year}),
            .day => try writer.print("{d:0>2}", .{dt.day}),
            .hour => try writer.print("{d:0>2}", .{dt.hour}),
            .min => try writer.print("{d:0>2}", .{dt.minute}),
            .sec => try writer.print("{d:0>2}", .{dt.second}),
            .nanos => try writer.print("{d:0>9}", .{dt.nanosecond}),
            .offset => try dt.formatOffset(writer),
            .tz_abbrev => try writer.print(
                "{s}", // use __abbrev_data directly since we have a copy of dt:
                .{std.mem.sliceTo(dt.tzinfo.?.tzOffset.?.__abbrev_data[0..], 0)},
            ),
            .doy => try writer.print("{d:0>3}", .{dt.dayOfYear()}),
            .percent_lit => try writer.print("%", .{}),
            // locale-specific:
            .day_name_abbr => try writer.print(
                "{s}",
                .{std.mem.sliceTo(getDayNameAbbr(dt.weekdayNumber())[0..], 0)},
            ),
            .day_name => try writer.print(
                "{s}",
                .{std.mem.sliceTo(getDayName(dt.weekdayNumber())[0..], 0)},
            ),
            .month_name_abbr => try writer.print(
                "{s}",
                .{std.mem.sliceTo(getMonthNameAbbr(dt.month - 1)[0..], 0)},
            ),
            .month_name => try writer.print(
                "{s}",
                .{std.mem.sliceTo(getMonthName(dt.month - 1)[0..], 0)},
            ),
            .isofmt => try dt.format("", .{}, writer),
        }
    }
};

/// Create a string representation of a Datetime
pub fn formatToString(writer: anytype, format: []const u8, dt: Datetime) !void {
    var next_char_is_specifier = false;
    for (format) |fc| {
        if (next_char_is_specifier) {
            const specifier = std.meta.intToEnum(FormatCode, fc) catch return error.InvalidSpecifier;
            try specifier.formatToString(writer, dt);
            next_char_is_specifier = false;
        } else {
            if (fc == '%') {
                next_char_is_specifier = true;
            } else {
                try writer.writeByte(fc);
            }
        }
    }
}

/// Create a Datetime from a string, with a compile-time-known format
pub fn parseToDatetime(comptime format: []const u8, dt_string: []const u8) !Datetime {
    var fields = Datetime.Fields{};

    comptime var next_char_is_specifier = false;
    var dt_string_idx: usize = 0;
    inline for (format) |fc| {
        if (next_char_is_specifier) {
            switch (fc) {
                'Y' => fields.year = try parseDigits(u16, dt_string, &dt_string_idx, 4),
                'm' => fields.month = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'd' => fields.day = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'H' => fields.hour = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'M' => fields.minute = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'S' => fields.second = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'f' => {
                    // if we only parse n digits out of 9, we have to multiply the result by
                    // 10^n to get nanoseconds
                    const tmp_idx = dt_string_idx;
                    fields.nanosecond = try parseDigits(u32, dt_string, &dt_string_idx, 9);
                    const missing = 9 - (dt_string_idx - tmp_idx);
                    const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
                    fields.nanosecond *= f;
                },
                'z' => { // UTC offset (+|-)hh[:mm[:ss]] or Z
                    const utcoffset = try parseOffset(i32, dt_string, &dt_string_idx, 9);
                    if (dt_string[dt_string_idx - 1] == 'Z') {
                        fields.tzinfo = Tz.UTC;
                    } else {
                        fields.tzinfo = try Tz.fromOffset(utcoffset, "");
                    }
                },
                'T' => return parseISO8601(dt_string),
                '%' => { // literal characters
                    if (dt_string[dt_string_idx] != fc) return error.InvalidFormat;
                    dt_string_idx += 1;
                },
                else => @compileError("Invalid format specifier '" ++ [_]u8{fc} ++ "'"),
            }
            next_char_is_specifier = false;
        } else {
            if (fc == '%') {
                next_char_is_specifier = true;
            } else {
                if (dt_string[dt_string_idx] != fc) {
                    return error.InvalidFormat;
                }
                dt_string_idx += 1;
            }
        }
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dt_string.len) {
        return error.InvalidFormat;
    }

    return Datetime.fromFields(fields);
}

/// Parse ISO8601 formats. Format is infered at runtime.
/// Requires at least a year and a month, separated by ASCII minus.
/// Date and time separator is either 'T' or ASCII space.
///
/// Examples:
/// ---
/// string                         len  datetime, normlized ISO8601
/// ------------------------------|----|------------------------------------
/// 2014-08                        7    2014-08-01T00:00:00
/// 2014-08-23                     10   2014-08-23T00:00:00
/// 2014-08-23 12:15               16   2014-08-23T12:15:00
/// 2014-08-23T12:15:56            19   2014-08-23T12:15:56
/// 2014-08-23T12:15:56.999999999Z 30   2014-08-23T12:15:56.999999999+00:00
/// 2014-08-23 12:15:56+01         22   2014-08-23T12:15:56+01:00
/// 2014-08-23T12:15:56-0530       24   2014-08-23T12:15:56-05:30
/// 2014-08-23T12:15:56+02:15:30   28   2014-08-23T12:15:56+02:15:30
pub fn parseISO8601(dt_string: []const u8) !Datetime {
    if (dt_string.len > 38) return error.InvalidFormat;
    if (dt_string[dt_string.len - 1] != 'Z' and !std.ascii.isDigit(dt_string[dt_string.len - 1])) {
        return error.InvalidFormat;
    }
    if (dt_string.len < 20) {
        switch (dt_string.len) {
            7, 10, 16, 19 => {},
            else => return error.InvalidFormat,
        }
    }

    var fields = Datetime.Fields{};
    var utcoffset: ?i32 = null;

    var dt_string_idx: usize = 0;
    // since this is a runtime-parser, we need to step through the input
    // and stop doing so once we reach the end (break the 'parseblock')
    parseblock: {
        // yyyy-mm
        fields.year = try parseDigits(u16, dt_string, &dt_string_idx, 4);
        if (dt_string_idx != 4) return error.InvalidFormat; // 2-digit year not allowed
        if (dt_string[dt_string_idx] != '-') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.month = try parseDigits(u8, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 7) return error.InvalidFormat; // 1-digit month not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-dd
        if (dt_string[dt_string_idx] != '-') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.day = try parseDigits(u8, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 10) return error.InvalidFormat; // 1-digit day not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM
        if (!(dt_string[dt_string_idx] == 'T' or dt_string[dt_string_idx] == ' ')) return error.InvalidFormat;
        dt_string_idx += 1;
        fields.hour = try parseDigits(u8, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 13) return error.InvalidFormat; // 1-digit hour not allowed
        if (dt_string[dt_string_idx] != ':') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.minute = try parseDigits(u8, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 16) return error.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS
        if (dt_string[dt_string_idx] != ':') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.second = try parseDigits(u8, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 19) return error.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS[+-](offset or Z)
        if (dt_string[dt_string_idx] == '+' or
            dt_string[dt_string_idx] == '-' or
            dt_string[dt_string_idx] == 'Z')
        {
            utcoffset = try parseOffset(i32, dt_string, &dt_string_idx, 9);
            if (dt_string_idx == dt_string.len) break :parseblock;
            return error.InvalidFormat; // offset must not befollowed by other fields
        }

        // yyyy-mm-ddTHH:MM:SS.fff (fractional seconds separator can either be '.' or ',')
        if (!(dt_string[dt_string_idx] == '.' or dt_string[dt_string_idx] == ',')) return error.InvalidFormat;
        dt_string_idx += 1;
        // parse any number of fractional seconds up to 9
        const tmp_idx = dt_string_idx;
        fields.nanosecond = try parseDigits(u32, dt_string, &dt_string_idx, 9);
        const missing = 9 - (dt_string_idx - tmp_idx);
        const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
        fields.nanosecond *= f;
        if (dt_string_idx == dt_string.len) break :parseblock;

        // trailing UTC offset
        utcoffset = try parseOffset(i32, dt_string, &dt_string_idx, 9);
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dt_string.len) {
        return error.InvalidFormat;
    }

    if (utcoffset != null) {
        if (dt_string[dt_string_idx - 1] == 'Z') {
            fields.tzinfo = Tz.UTC;
        } else {
            fields.tzinfo = try Tz.fromOffset(utcoffset.?, "");
        }
    }

    return Datetime.fromFields(fields);
}

// ----- String to Datetime Helpers -----------------

// for any numeric quantity
fn parseDigits(comptime T: type, dt_string: []const u8, idx: *usize, maxDigits: usize) !T {
    const start_idx = idx.*;
    if (!std.ascii.isDigit(dt_string[start_idx])) return error.InvalidFormat;

    idx.* += 1;
    while (idx.* < dt_string.len and // check first if dt_string depleted
        idx.* < start_idx + maxDigits and
        std.ascii.isDigit(dt_string[idx.*])) : (idx.* += 1)
    {}

    return try std.fmt.parseInt(T, dt_string[start_idx..idx.*], 10);
}

// offset UTC in the from of (+|-)hh[:mm[:ss]] or Z
fn parseOffset(comptime T: type, dt_string: []const u8, idx: *usize, maxDigits: usize) !T {
    const start_idx = idx.*;

    var sign: i2 = 1;
    switch (dt_string[start_idx]) {
        '+' => sign = 1,
        '-' => sign = -1,
        'Z' => {
            idx.* += 1;
            return 0;
        },
        else => return error.InvalidFormat, // must start with sign
    }

    idx.* += 1;
    while (idx.* < dt_string.len and // check first if dt_string depleted
        idx.* < start_idx + maxDigits and
        (std.ascii.isDigit(dt_string[idx.*]) or dt_string[idx.*] == ':')) : (idx.* += 1)
    {}

    // clean offset string:
    var index: usize = 0;
    var offset_chars = [6]u8{ 48, 48, 48, 48, 48, 48 }; // start with 000000;
    for (dt_string[start_idx + 1 .. idx.*]) |c| { //                  hhmmss
        if (c != ':') {
            offset_chars[index] = c;
            index += 1;
        }
        if (index == 6) break;
    }
    if (index < 2) return error.InvalidFormat; // offset must be at least 2 chars

    const i = std.fmt.parseInt(T, &offset_chars, 10) catch return error.InvalidFormat;
    const hours = @divFloor(i, 10000);
    const remainder = @mod(i, 10000);
    const minutes = @divFloor(remainder, 100);
    const seconds = @mod(remainder, 100);
    return sign * (hours * 3600 + minutes * 60 + seconds);
}

// -----
// helpers for %a %A %b %B
// ----->
const sz_abbr: usize = 32;
const sz_normal: usize = 64;

// Get the abbreviated day name in the current locale
fn getDayNameAbbr(n: u8) [sz_abbr]u8 {
    var dummy: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    dummy[0] = 63;
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getDayNameAbbr_(n),
        .windows => windows_specific.getDayNameAbbr_(n),
        else => dummy,
    };
}

// Get the day name in the current locale
fn getDayName(n: u8) [sz_normal]u8 {
    var dummy: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    dummy[0] = 63;
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getDayName_(n),
        .windows => windows_specific.getDayName_(n),
        else => dummy,
    };
}

// Get the abbreviated month name in the current locale
fn getMonthNameAbbr(n: u8) [sz_abbr]u8 {
    var dummy: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    dummy[0] = 63;
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getMonthNameAbbr_(n),
        .windows => windows_specific.getMonthNameAbbr_(n),
        else => dummy,
    };
}

// Get the month name in the current locale
fn getMonthName(n: u8) [sz_normal]u8 {
    var dummy: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    dummy[0] = 63;
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getMonthName_(n),
        .windows => windows_specific.getMonthName_(n),
        else => dummy,
    };
}
