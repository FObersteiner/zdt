//! conversion between datetime and string representation

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.zdt__stringIO);

const Datetime = @import("./Datetime.zig");
const Tz = @import("./Timezone.zig");
const ZdtError = @import("./errors.zig").ZdtError;
const FormatError = @import("./errors.zig").FormatError;
const unix_specific = @import("./unix/unix_mdnames.zig");
const windows_specific = @import("./windows/windows_mdnames.zig");

/// directives to create string representation of a datetime
const FormatCode = enum(u8) {
    day = 'd',
    day_name_abbr = 'a', // locale-specific
    day_name = 'A', // locale-specific
    month = 'm',
    month_name_abbr = 'b', // locale-specific
    month_name = 'B', // locale-specific
    year = 'Y',
    year_2digit = 'y',
    year_iso = 'G',
    hour = 'H',
    hour12 = 'I', // 12-hour clock, requires %p as well
    am_pm = 'p',
    min = 'M',
    sec = 'S',
    nanos = 'f',
    offset = 'z',
    tz_abbrev = 'Z',
    iana_tz_name = 'i',
    doy = 'j',
    weekday = 'w',
    weekday_iso = 'u',
    week_of_year = 'U',
    week_of_year_mon = 'W',
    week_of_year_iso = 'V',
    iso8601 = 'T',
    // loc_date = 'x', // locale-specific
    // loc_time = 'X', // locale-specific
    // loc_datetime = 'c', // locale-specific
    percent_lit = '%',

    /// create string representation of datetime fields and properties
    pub fn stringify(
        fc: FormatCode,
        writer: anytype,
        dt: Datetime,
    ) !void {
        switch (fc) {
            .day => try writer.print("{d:0>2}", .{dt.day}),
            .day_name_abbr => try writer.print("{s}", .{std.mem.sliceTo(getDayNameAbbr(dt.weekdayNumber())[0..], 0)}),
            .day_name => try writer.print("{s}", .{std.mem.sliceTo(getDayName(dt.weekdayNumber())[0..], 0)}),
            .month => try writer.print("{d:0>2}", .{dt.month}),
            .month_name_abbr => try writer.print("{s}", .{std.mem.sliceTo(getMonthNameAbbr(dt.month - 1)[0..], 0)}),
            .month_name => try writer.print("{s}", .{std.mem.sliceTo(getMonthName(dt.month - 1)[0..], 0)}),
            .year => try writer.print("{d:0>4}", .{dt.year}),
            .year_2digit => try writer.print("{d:0>2}", .{dt.year % 100}),
            .year_iso => try writer.print("{d:0>4}", .{dt.year}),
            .hour => try writer.print("{d:0>2}", .{dt.hour}),
            .hour12 => try writer.print("{d:0>2}", .{twelve_hour_format(dt.hour)}),
            .am_pm => try writer.print("{s}", .{if (dt.hour < 12) "am" else "pm"}),
            .min => try writer.print("{d:0>2}", .{dt.minute}),
            .sec => try writer.print("{d:0>2}", .{dt.second}),
            .nanos => try writer.print("{d:0>9}", .{dt.nanosecond}),
            .offset => try dt.formatOffset(writer),
            .tz_abbrev => blk: {
                if (dt.isNaive()) break :blk;
                try writer.print("{s}", .{@constCast(&dt.tzinfo.?).abbreviation()});
            },
            .iana_tz_name => blk: {
                if (dt.isNaive()) break :blk;
                try writer.print("{s}", .{@constCast(&dt.tzinfo.?).name()});
            },
            .doy => try writer.print("{d:0>3}", .{dt.dayOfYear()}),
            .weekday => try writer.print("{d}", .{Datetime.weekdayNumber(dt)}),
            .weekday_iso => try writer.print("{d}", .{Datetime.weekdayIsoNumber(dt)}),
            .week_of_year => try writer.print("{d:0>2}", .{Datetime.weekOfYearSun(dt)}),
            .week_of_year_mon => try writer.print("{d:0>2}", .{Datetime.weekOfYearMon(dt)}),
            .week_of_year_iso => try writer.print("{d:0>2}", .{Datetime.toISOCalendar(dt).isoweek}),
            .iso8601 => try dt.format("", .{}, writer),
            // .loc_date => @compileError("not implemented"),
            // .loc_time => @compileError("not implemented"),
            // .loc_datetime => @compileError("not implemented"),
            .percent_lit => try writer.print("%", .{}),
        }
    }
};

/// Create a string representation of a Datetime
pub fn formatToString(dt: Datetime, format: []const u8, writer: anytype) FormatError!void {
    var next_char_is_specifier = false;
    for (format) |fc| {
        if (next_char_is_specifier) {
            const specifier = std.meta.intToEnum(FormatCode, fc) catch return FormatError.InvalidDirective;
            try specifier.stringify(writer, dt);
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
pub fn parseToDatetime(dt_string: []const u8, comptime format: []const u8) ZdtError!Datetime {
    var fields = Datetime.Fields{};

    comptime var next_char_is_specifier = false;
    var dt_string_idx: usize = 0;
    var am_pm_flags: u8 = 0; // bits; 0 - am, 1 - pm, 2 - found %I

    inline for (format) |fc| {
        if (next_char_is_specifier) {
            switch (fc) {
                'd' => fields.day = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                // 'a'
                // 'A'
                'm' => fields.month = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                // 'b'
                // 'B'
                'Y' => fields.year = try parseDigits(u16, dt_string, &dt_string_idx, 4),
                'y' => fields.year = try parseDigits(u16, dt_string, &dt_string_idx, 2) + Datetime.century,
                // 'G'
                'H' => fields.hour = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'I' => fields.hour = blk: { // must be in [1..12]
                    const h = try parseDigits(u8, dt_string, &dt_string_idx, 2);
                    am_pm_flags |= 4;
                    if (h >= 1 and h <= 12) break :blk h else return FormatError.InvalidFormat;
                },
                'M' => fields.minute = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'S' => fields.second = try parseDigits(u8, dt_string, &dt_string_idx, 2),
                'p' => am_pm_flags |= try parseAmPm(dt_string, &dt_string_idx),
                'f' => {
                    // if we only parse n digits out of 9, we have to multiply the result by
                    // 10^n to get nanoseconds
                    const tmp_idx = dt_string_idx;
                    fields.nanosecond = try parseDigits(u32, dt_string, &dt_string_idx, 9);
                    const missing = 9 - (dt_string_idx - tmp_idx);
                    const f: u32 = std.math.powi(u32, 10, @as(u32, @intCast(missing))) catch
                        return FormatError.InvalidFraction;
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
                // 'j'
                // 'w'
                // 'u'
                // 'W'
                // 'U'
                // 'V'
                // 'x' // locale-specific
                // 'X' // locale-specific
                // 'c' // locale-specific
                'T' => return parseISO8601(dt_string),
                '%' => { // literal characters
                    if (dt_string[dt_string_idx] != fc) return FormatError.InvalidFormat;
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
                    return FormatError.InvalidFormat;
                }
                dt_string_idx += 1;
            }
        }
    }

    switch (am_pm_flags) {
        0 => {}, // neither %I nor am/pm in input string
        5 => fields.hour = fields.hour % 12, // 0101, %I and 'am'
        6 => fields.hour = fields.hour % 12 + 12, // 0110, %I and 'pm'
        else => return FormatError.InvalidFormat, // might be %I but no %p or vice versa
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dt_string.len) {
        return FormatError.InvalidFormat;
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
pub fn parseISO8601(dt_string: []const u8) ZdtError!Datetime {
    if (dt_string.len > 38) // 9 digits of fractional seconds and hh:mm:ss UTC offset
        return FormatError.InvalidFormat;
    if (dt_string[dt_string.len - 1] != 'Z' and !std.ascii.isDigit(dt_string[dt_string.len - 1])) {
        return FormatError.InvalidFormat;
    }
    if (dt_string.len < 20) {
        switch (dt_string.len) {
            7, 10, 16, 19 => {},
            else => return FormatError.InvalidFormat,
        }
    }

    var fields = Datetime.Fields{};
    var utcoffset: ?i32 = null;
    var dt_string_idx: usize = 0;

    // since this is a runtime-parser, we need to step through the input
    // and stop doing so once we reach the end (break the 'parseblock')
    parseblock: {
        // yyyy-mm
        fields.year = parseDigits(u16, dt_string, &dt_string_idx, 4) catch return FormatError.ParseIntError;
        if (dt_string_idx != 4) return FormatError.InvalidFormat; // 2-digit year not allowed
        if (dt_string[dt_string_idx] != '-') return FormatError.InvalidFormat;
        dt_string_idx += 1;
        fields.month = parseDigits(u8, dt_string, &dt_string_idx, 2) catch return FormatError.ParseIntError;
        if (dt_string_idx != 7) return FormatError.InvalidFormat; // 1-digit month not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-dd
        if (dt_string[dt_string_idx] != '-') return FormatError.InvalidFormat;
        dt_string_idx += 1;
        fields.day = parseDigits(u8, dt_string, &dt_string_idx, 2) catch return FormatError.ParseIntError;
        if (dt_string_idx != 10) return FormatError.InvalidFormat; // 1-digit day not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM
        if (!(dt_string[dt_string_idx] == 'T' or dt_string[dt_string_idx] == ' ')) return FormatError.InvalidFormat;
        dt_string_idx += 1;
        fields.hour = parseDigits(u8, dt_string, &dt_string_idx, 2) catch return FormatError.ParseIntError;
        if (dt_string_idx != 13) return FormatError.InvalidFormat; // 1-digit hour not allowed
        if (dt_string[dt_string_idx] != ':') return FormatError.InvalidFormat;
        dt_string_idx += 1;
        fields.minute = parseDigits(u8, dt_string, &dt_string_idx, 2) catch return FormatError.ParseIntError;
        if (dt_string_idx != 16) return FormatError.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS
        if (dt_string[dt_string_idx] != ':') return FormatError.InvalidFormat;
        dt_string_idx += 1;
        fields.second = parseDigits(u8, dt_string, &dt_string_idx, 2) catch return FormatError.ParseIntError;
        if (dt_string_idx != 19) return FormatError.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS[+-](offset or Z)
        if (dt_string[dt_string_idx] == '+' or
            dt_string[dt_string_idx] == '-' or
            dt_string[dt_string_idx] == 'Z')
        {
            utcoffset = try parseOffset(i32, dt_string, &dt_string_idx, 9);
            if (dt_string_idx == dt_string.len) break :parseblock;
            return FormatError.InvalidFormat; // offset must not befollowed by other fields
        }

        // yyyy-mm-ddTHH:MM:SS.fff (fractional seconds separator can either be '.' or ',')
        if (!(dt_string[dt_string_idx] == '.' or dt_string[dt_string_idx] == ',')) return FormatError.InvalidFormat;
        dt_string_idx += 1;
        // parse any number of fractional seconds up to 9
        const tmp_idx = dt_string_idx;
        fields.nanosecond = parseDigits(u32, dt_string, &dt_string_idx, 9) catch return FormatError.ParseIntError;
        const missing = 9 - (dt_string_idx - tmp_idx);
        const f: u32 = std.math.powi(u32, 10, @as(u32, @intCast(missing))) catch return FormatError.InvalidFraction;
        fields.nanosecond *= f;
        if (dt_string_idx == dt_string.len) break :parseblock;

        // trailing UTC offset
        utcoffset = try parseOffset(i32, dt_string, &dt_string_idx, 9);
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dt_string.len) {
        return FormatError.InvalidFormat;
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

fn parseAmPm(dt_string: []const u8, idx: *usize) FormatError!u8 {
    if (idx.* + 2 > dt_string.len) return FormatError.InvalidFormat;

    var flag: u8 = 0;
    flag = switch (std.ascii.toLower(dt_string[idx.*])) {
        'a' => 1,
        'p' => 2,
        else => return FormatError.InvalidFormat,
    };

    idx.* += 1;
    if (std.ascii.toLower(dt_string[idx.*]) != 'm') return FormatError.InvalidFormat;

    idx.* += 1;
    return flag;
}

// for any numeric quantity
fn parseDigits(comptime T: type, dt_string: []const u8, idx: *usize, maxDigits: usize) FormatError!T {
    const start_idx = idx.*;
    if (!std.ascii.isDigit(dt_string[start_idx])) return FormatError.InvalidFormat;

    idx.* += 1;
    while (idx.* < dt_string.len and // check first if dt_string depleted
        idx.* < start_idx + maxDigits and
        std.ascii.isDigit(dt_string[idx.*])) : (idx.* += 1)
    {}

    return std.fmt.parseInt(T, dt_string[start_idx..idx.*], 10) catch FormatError.ParseIntError;
}

// offset UTC in the from of (+|-)hh[:mm[:ss]] or Z
fn parseOffset(comptime T: type, dt_string: []const u8, idx: *usize, maxDigits: usize) FormatError!T {
    const start_idx = idx.*;

    var sign: i2 = 1;
    switch (dt_string[start_idx]) {
        '+' => sign = 1,
        '-' => sign = -1,
        'Z' => {
            idx.* += 1;
            return 0;
        },
        else => return FormatError.InvalidFormat, // must start with sign
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
    if (index < 2) return FormatError.InvalidFormat; // offset must be at least 2 chars

    const i = std.fmt.parseInt(T, &offset_chars, 10) catch return FormatError.ParseIntError;
    const hours = @divFloor(i, 10000);
    const remainder = @mod(i, 10000);
    const minutes = @divFloor(remainder, 100);
    const seconds = @mod(remainder, 100);
    return sign * (hours * 3600 + minutes * 60 + seconds);
}

// Turn 24 hour clock into 12 hour clock
fn twelve_hour_format(hour: u8) u8 {
    return if (hour == 0 or hour == 12) 12 else hour % 12;
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
