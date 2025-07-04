//! conversion between datetime and string representation

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const log = std.log.scoped(.zdt__string);

const Datetime = @import("./Datetime.zig");
const cal = @import("./calendar.zig");
const Tz = @import("./Timezone.zig");
const UTCoffset = @import("./UTCoffset.zig");

const ZdtError = @import("./errors.zig").ZdtError;
const FormatError = @import("./errors.zig").FormatError;
const unix_specific = @import("./unix/unix_mdnames.zig");
const windows_specific = @import("./windows/windows_mdnames.zig");

const TokenizerState = enum(u8) {
    ExpectChar,
    ExpectDirectiveOrModifier,
    ProcessChar,
    ProcessDirective,
    Finalize,
};

const token_start: u8 = '%';
const modifier: u8 = ':';

const ParserFlags = enum(u32) {
    OK = 0,
    AM = 1,
    PM = 2,
    clock_12h = 4,
};

/// Tokenize the parsing directives and parse the datetime string accordingly.
pub fn tokenizeAndParse(data: []const u8, directives: []const u8) ZdtError!Datetime {
    var fmt_idx: usize = 0;
    var data_idx: usize = 0;
    var flags: u32 = 0;
    var modifier_count: u8 = 0;
    var fields = Datetime.Fields{};

    tokenize: switch (TokenizerState.ExpectChar) {
        TokenizerState.ExpectChar => {
            if (directives[fmt_idx] == token_start) {
                fmt_idx += 1;
                if (fmt_idx >= directives.len) return FormatError.InvalidFormat;
                continue :tokenize .ExpectDirectiveOrModifier;
            }
            continue :tokenize .ProcessChar;
        },
        TokenizerState.ExpectDirectiveOrModifier => {
            if (directives[fmt_idx] == modifier) {
                modifier_count += 1;
                fmt_idx += 1;
                continue :tokenize .ExpectDirectiveOrModifier;
            }
            if (directives[fmt_idx] == token_start) { // special case: literal 'token_start'
                continue :tokenize .ProcessChar;
            }
            continue :tokenize .ProcessDirective;
        },
        TokenizerState.ProcessChar => {
            if (data[data_idx] != directives[fmt_idx]) return FormatError.InvalidFormat;
            data_idx += 1;
            fmt_idx += 1;
            if ((data_idx >= data.len) or (fmt_idx >= directives.len)) continue :tokenize .Finalize;
            continue :tokenize .ExpectChar;
        },
        TokenizerState.ProcessDirective => {
            try parseIntoFields(&fields, data, directives[fmt_idx], &data_idx, &flags, modifier_count);
            fmt_idx += 1;
            modifier_count = 0; // any directive starts with modifier = 0
            if (fmt_idx >= directives.len) continue :tokenize .Finalize;
            continue :tokenize .ExpectChar;
        },
        TokenizerState.Finalize => {
            if (fmt_idx != directives.len) return FormatError.InvalidDirective;
            if (data_idx != data.len) return FormatError.InvalidFormat;
            switch (flags) {
                0b000 => {}, // neither %I nor am/pm in input string
                0b101 => fields.hour = fields.hour % 12, //  %I and 'am'
                0b110 => fields.hour = fields.hour % 12 + 12, //  %I and 'pm'
                else => return FormatError.InvalidFormat, // might be %I but no %p or vice versa
            }
            break :tokenize;
        },
    }

    return try Datetime.fromFields(fields);
}

/// Tokenize the formatting directives and print to the writer interface.
pub fn tokenizeAndPrint(
    dt: *const Datetime,
    directives: []const u8,
    writer: anytype,
) anyerror!void { // have to use 'anyerror' here due to the 'anytype' writer
    var fmt_idx: usize = 0;
    var modifier_count: u8 = 0;

    tokenize: switch (TokenizerState.ExpectChar) {
        TokenizerState.ExpectChar => {
            if (directives[fmt_idx] == token_start) {
                fmt_idx += 1;
                if (fmt_idx >= directives.len) return FormatError.InvalidFormat;
                continue :tokenize .ExpectDirectiveOrModifier;
            }
            continue :tokenize .ProcessChar;
        },
        TokenizerState.ExpectDirectiveOrModifier => {
            if (directives[fmt_idx] == modifier) {
                modifier_count += 1;
                fmt_idx += 1;
                if (fmt_idx >= directives.len) continue :tokenize .Finalize;
                continue :tokenize .ExpectDirectiveOrModifier;
            }
            continue :tokenize .ProcessDirective;
        },
        TokenizerState.ProcessChar => {
            try writer.print("{c}", .{directives[fmt_idx]});
            fmt_idx += 1;
            if (fmt_idx >= directives.len) continue :tokenize .Finalize;
            continue :tokenize .ExpectChar;
        },
        TokenizerState.ProcessDirective => {
            try printIntoWriter(dt, directives[fmt_idx], modifier_count, writer);
            modifier_count = 0;
            fmt_idx += 1;
            if (fmt_idx >= directives.len) continue :tokenize .Finalize;
            continue :tokenize .ExpectChar;
        },
        TokenizerState.Finalize => {
            if (fmt_idx != directives.len) return FormatError.InvalidDirective;
            break :tokenize;
        },
    }
}

/// The function that actually fills datetime fields with data.
fn parseIntoFields(
    fields: *Datetime.Fields,
    string: []const u8,
    directive: u8,
    idx_ptr: *usize,
    flags: *u32,
    modifier_count: u8,
) ZdtError!void {
    switch (directive) {
        'd' => fields.day = try parseDigits(u8, string, idx_ptr, 2),
        // 'e' - use 'd'
        'a' => {
            const names = switch (modifier_count) {
                0 => try allDayNamesShort(),
                1 => allDayNamesShortEng(),
                else => return FormatError.InvalidFormat,
            };
            _ = try parseDayNameAbbr(string, idx_ptr, &names);
        },
        'A' => {
            const names = switch (modifier_count) {
                0 => try allDayNames(),
                1 => allDayNamesEng(),
                else => return FormatError.InvalidFormat,
            };
            _ = try parseDayName(string, idx_ptr, &names);
        },
        'm' => fields.month = try parseDigits(u8, string, idx_ptr, 2),
        'b' => {
            const names = switch (modifier_count) {
                0 => try allMonthNamesShort(),
                1 => allMonthNamesShortEng(),
                else => return FormatError.InvalidFormat,
            };
            fields.month = try parseMonthNameAbbr(string, idx_ptr, &names);
        },
        'B' => {
            const names = switch (modifier_count) {
                0 => try allMonthNames(),
                1 => allMonthNamesEng(),
                else => return FormatError.InvalidFormat,
            };
            fields.month = try parseMonthName(string, idx_ptr, &names);
        },

        'Y' => fields.year = try parseDigits(i16, string, idx_ptr, 4),
        'y' => fields.year = try parseDigits(i16, string, idx_ptr, 2) + Datetime.century,
        // 'C', - formatting-only
        // 'G',
        'H' => fields.hour = try parseDigits(u8, string, idx_ptr, 2),
        // 'k' - use 'H'
        'I' => fields.hour = blk: { // must be in [1..12]
            const h = try parseDigits(u8, string, idx_ptr, 2);
            flags.* |= @intFromEnum(ParserFlags.clock_12h);
            if (h >= 1 and h <= 12) break :blk h else return FormatError.InvalidFormat;
        },
        'P' => flags.* |= @intFromEnum(try parseAmPm(string, idx_ptr)),
        'p' => flags.* |= @intFromEnum(try parseAmPm(string, idx_ptr)),
        'M' => fields.minute = try parseDigits(u8, string, idx_ptr, 2),
        'S' => fields.second = try parseDigits(u8, string, idx_ptr, 2),
        'f' => {
            // if we only parse n digits out of 9, we have to multiply the result by
            // 10^n to get nanoseconds
            const tmp_idx = idx_ptr.*;
            fields.nanosecond = try parseDigits(u32, string, idx_ptr, 9);
            const missing = 9 - (idx_ptr.* - tmp_idx);
            const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
            fields.nanosecond *= f;
        },
        'z' => { // UTC offset (+|-)hh[:mm[:ss]] or Z
            const utcoffset = try parseOffset(i32, string, idx_ptr, 9);
            if (string[idx_ptr.* - 1] == 'Z')
                fields.tz_options = .{ .utc_offset = UTCoffset.UTC }
            else
                fields.tz_options = .{ .utc_offset = try UTCoffset.fromSeconds(utcoffset, "", false) };
        },
        // 'Z', - ambiguous!
        // 'i', - IANA identifier; would require allocator
        'j' => {
            const doy = try parseDigits(u16, string, idx_ptr, 3);
            if (doy == 0) return FormatError.InvalidFormat;
            if (doy > 365 + @as(u16, @intFromBool(cal.isLeapYear(fields.year)))) return FormatError.InvalidFormat;
            const date = cal.rdToDate(cal.dateToRD(.{ .year = fields.year, .month = 1, .day = 1 }) + doy - 1);
            fields.month = @truncate(date.month);
            fields.day = @truncate(date.day);
        },
        // 'w',
        // 'u',
        // 'W',
        // 'U',
        // 'V',
        'T' => { // T: full ISO format
            fields.* = try parseISO8601(string, idx_ptr);
        },
        // 'F' => ISO date only?
        't' => {
            const ical = try Datetime.ISOCalendar.fromString(string[idx_ptr.*..]);
            const tmp_dt = try ical.toDatetime();
            idx_ptr.* += 10;
            fields.*.year = tmp_dt.year;
            fields.*.month = tmp_dt.month;
            fields.*.day = tmp_dt.day;
        },
        // 'x', // locale-specific, date
        // 'X', // locale-specific, time
        // 'c', // locale-specific, datetime
        else => return FormatError.InvalidDirective,
    }
}

/// The function that actually prints to the writer interface.
fn printIntoWriter(
    dt: *const Datetime,
    directive: u8,
    modifier_count: u8,
    writer: anytype,
) anyerror!void { // have to use 'anyerror' here due to the 'anytype' writer
    switch (directive) {
        'd' => try writer.print("{d:0>2}", .{dt.day}),
        'e' => try writer.print("{d: >2}", .{dt.day}),
        'a' => {
            switch (modifier_count) {
                0 => {
                    const name = try getDayNameAbbr(dt.weekdayNumber()); // locale-specific, day name short
                    try writer.print("{s}", .{std.mem.sliceTo(&name, 0)});
                },
                1 => try writer.print("{s}", .{dt.weekday().shortName()}), // English default
                else => return FormatError.InvalidFormat,
            }
        },
        'A' => {
            switch (modifier_count) {
                0 => {
                    const name = try getDayName(dt.weekdayNumber()); // locale-specific, day name
                    try writer.print("{s}", .{std.mem.sliceTo(&name, 0)});
                },
                1 => try writer.print("{s}", .{dt.weekday().longName()}), // English default
                else => return FormatError.InvalidFormat,
            }
        },
        'm' => try writer.print("{d:0>2}", .{dt.month}),
        'b' => {
            switch (modifier_count) {
                0 => {
                    const name = try getMonthNameAbbr(dt.month - 1); // locale-specific, month name short
                    try writer.print("{s}", .{std.mem.sliceTo(&name, 0)});
                },
                1 => try writer.print("{s}", .{dt.monthEnum().shortName()}), // English default
                else => return FormatError.InvalidFormat,
            }
        },
        'B' => {
            switch (modifier_count) {
                0 => {
                    const name = try getMonthName(dt.month - 1); // locale-specific, month name
                    try writer.print("{s}", .{std.mem.sliceTo(&name, 0)});
                },
                1 => try writer.print("{s}", .{dt.monthEnum().longName()}), // English default
                else => return FormatError.InvalidFormat,
            }
        },
        'Y' => try writer.print("{s}{d:0>4}", .{ if (dt.year < 0) "-" else "", @abs(dt.year) }),
        'y' => try writer.print("{s}{d:0>2}", .{ if (dt.year < 0) "-" else "", @abs(@mod(dt.year, 100)) }),
        'C' => try writer.print("{s}{d:0>2}", .{ if (dt.year < 0) "-" else "", @abs(@divFloor(dt.year, 100)) }),
        'G' => try writer.print("{s}{d:0>4}", .{ if (dt.toISOCalendar().isoyear < 0) "-" else "", dt.toISOCalendar().isoyear }),
        'H' => try writer.print("{d:0>2}", .{dt.hour}),
        'k' => try writer.print("{d: >2}", .{dt.hour}),
        'I' => try writer.print("{d:0>2}", .{twelve_hour_format(dt.hour)}),
        'P' => try writer.print("{s}", .{if (dt.hour < 12) "AM" else "PM"}),
        'p' => try writer.print("{s}", .{if (dt.hour < 12) "am" else "pm"}),
        'M' => try writer.print("{d:0>2}", .{dt.minute}),
        'S' => try writer.print("{d:0>2}", .{dt.second}),
        'f' => {
            switch (modifier_count) {
                0 => try writer.print("{d:0>9}", .{dt.nanosecond}), // 'f' 123456789
                1 => try writer.print("{d:0>3}", .{dt.nanosecond / 1000000}), // 'f:' 123
                2 => try writer.print("{d:0>6}", .{dt.nanosecond / 1000}), // 'f::' 123456
                else => return FormatError.InvalidFormat,
            }
        },
        'z' => blk: {
            if (dt.isNaive()) break :blk;
            switch (modifier_count) {
                0 => try dt.formatOffset(.{ .fill = 0, .precision = 1 }, writer), // 'z' +0100
                1 => try dt.formatOffset(.{ .fill = ':', .precision = 1 }, writer), // 'z:' +01:00
                2 => try dt.formatOffset(.{ .fill = ':', .precision = 2 }, writer), // 'z::' +01:00:00
                3 => try dt.formatOffset(.{ .fill = ':', .precision = 0 }, writer), // 'z:::' +01
                else => return FormatError.InvalidFormat,
            }
        },
        'Z' => blk: {
            if (dt.isNaive()) break :blk;
            const offset = dt.utc_offset.?; // !isNaive asserts that offset is not null
            switch (modifier_count) {
                0 => try writer.print("{s}", .{offset.designation()}),
                1 => {
                    if (std.meta.eql(offset, UTCoffset.UTC))
                        try writer.print("Z", .{})
                    else
                        try writer.print("{s}", .{offset.designation()});
                },
                else => return FormatError.InvalidFormat,
            }
        },
        'i' => blk: {
            if (dt.isNaive()) break :blk;
            try writer.print("{s}", .{dt.tzName()});
        },
        'j' => try writer.print("{d:0>3}", .{dt.dayOfYear()}),
        'w' => try writer.print("{d}", .{dt.weekdayNumber()}),
        'u' => try writer.print("{d}", .{dt.weekdayIsoNumber()}),
        'W' => try writer.print("{d:0>2}", .{dt.weekOfYearMon()}),
        'U' => try writer.print("{d:0>2}", .{dt.weekOfYearSun()}),
        'V' => try writer.print("{d:0>2}", .{dt.toISOCalendar().isoweek}),
        'T' => try dt.format("", .{}, writer), // ISO format
        // 'F' => try dt.format("", .{}, writer) // ISO format, date only
        't' => try writer.print("{s}", .{dt.toISOCalendar()}),
        // 'x', // locale-specific, date
        // 'X', // locale-specific, time
        // 'c', // locale-specific, datetime
        's' => try writer.print("{d}", .{dt.unix_sec}),
        '%' => try writer.print("%", .{}),
        else => return FormatError.InvalidDirective,
    }
}

/// Parse exactly nDigits to an integer.
/// Return error.InvalidFormat if something goes wrong.
fn parseExactNDigits(comptime T: type, string: []const u8, idx_ptr: *usize, nDigits: usize) FormatError!T {
    if ((string.len - idx_ptr.*) < nDigits)
        return FormatError.InvalidFormat;
    idx_ptr.* += nDigits;

    return std.fmt.parseInt(T, string[idx_ptr.* - nDigits .. idx_ptr.*], 10);
}

/// Parse up to  maxDigits to an integer.
/// Return error.InvalidFormat if something goes wrong.
fn parseDigits(comptime T: type, string: []const u8, idx_ptr: *usize, maxDigits: usize) FormatError!T {
    const start_idx = idx_ptr.*;
    idx_ptr.* += 1;
    while (idx_ptr.* < string.len and // check first if string depleted
        idx_ptr.* < start_idx + maxDigits and
        std.ascii.isDigit(string[idx_ptr.*])) : (idx_ptr.* += 1)
    {}

    return std.fmt.parseInt(T, string[start_idx..idx_ptr.*], 10);
}

// AM or PM string, no matter if upper or lower case.
fn parseAmPm(string: []const u8, idx_ptr: *usize) FormatError!ParserFlags {
    if (idx_ptr.* + 2 > string.len) return FormatError.InvalidFormat;

    const flag = switch (std.ascii.toLower(string[idx_ptr.*])) {
        'a' => ParserFlags.AM,
        'p' => ParserFlags.PM,
        else => return FormatError.InvalidFormat,
    };

    idx_ptr.* += 1;
    if (std.ascii.toLower(string[idx_ptr.*]) != 'm') return FormatError.InvalidFormat;
    idx_ptr.* += 1;

    return flag;
}

// Turn 24 hour clock into 12 hour clock.
fn twelve_hour_format(hour: u8) u8 {
    return if (hour == 0 or hour == 12) 12 else hour % 12;
}

// Offset UTC in the from of (+|-)hh[:mm[:ss]] or Z.
fn parseOffset(comptime T: type, string: []const u8, idx_ptr: *usize, maxDigits: usize) FormatError!T {
    const start_idx = idx_ptr.*;

    var sign: i2 = 1;
    switch (string[start_idx]) {
        '+' => sign = 1,
        '-' => sign = -1,
        'Z' => {
            idx_ptr.* += 1;
            return 0;
        },
        else => return FormatError.InvalidCharacter, // must start with sign or UTC indicator
    }

    idx_ptr.* += 1;
    while (idx_ptr.* < string.len and // check first if string depleted
        idx_ptr.* < start_idx + maxDigits and
        (std.ascii.isDigit(string[idx_ptr.*]) or string[idx_ptr.*] == ':')) : (idx_ptr.* += 1)
    {}

    // clean offset string:
    var index: usize = 0;
    var offset_chars = [6]u8{ 48, 48, 48, 48, 48, 48 }; // start with 000000;
    for (string[start_idx + 1 .. idx_ptr.*]) |c| { //                 hhmmss
        if (c != ':') {
            offset_chars[index] = c;
            index += 1;
        }
        if (index == 6) break;
    }
    if (index < 2) return FormatError.InvalidFormat; // offset must be at least 2 chars

    const i = try std.fmt.parseInt(T, &offset_chars, 10);
    const hours = @divFloor(i, 10000);
    const remainder = @mod(i, 10000);
    const minutes = @divFloor(remainder, 100);
    const seconds = @mod(remainder, 100);
    return sign * (hours * 3600 + minutes * 60 + seconds);
}

const ISOParserState = enum(u8) {
    Year,
    Ordinal,
    Month,
    Day,
    DateTimeSep,
    Hour,
    Minute,
    Second,
    Fraction,
    Offset,
};

/// Parse ISO8601 formats. The format is inferred at runtime.
/// Requires at least a year and a month, separated by ASCII minus.
/// Date and time separator is either 'T' or ASCII space.
///
/// Examples:
/// ---
/// string                         len  datetime, normalized ISO8601
/// ------------------------------|----|------------------------------------
/// 2014-08                        7    2014-08-01T00:00:00
/// 2014-08-23                     10   2014-08-23T00:00:00
/// 2014-08-23 12:15               16   2014-08-23T12:15:00
/// 2014-08-23T12:15:56            19   2014-08-23T12:15:56
/// 2014-08-23T12:15:56.999999999Z 30   2014-08-23T12:15:56.999999999+00:00
/// 2014-08-23 12:15:56+01         22   2014-08-23T12:15:56+01:00
/// 2014-08-23T12:15:56-0530       24   2014-08-23T12:15:56-05:30
/// 2014-08-23T12:15:56+02:15:30   28   2014-08-23T12:15:56+02:15:30
pub fn parseISO8601(string: []const u8, idx_ptr: *usize) ZdtError!Datetime.Fields {
    var fields = Datetime.Fields{};

    parsing: switch (ISOParserState.Year) {
        .Year => {
            fields.year = try parseExactNDigits(i16, string, idx_ptr, 4);
            if (idx_ptr.* == string.len) return FormatError.InvalidFormat; // year-only not allowed
            if (string[idx_ptr.*] == '-') idx_ptr.* += 1; // opt. y-m separator
            if (idx_ptr.* >= string.len) break :parsing;
            if (string[idx_ptr.*..].len == 3) continue :parsing .Ordinal else continue :parsing .Month;
        },
        .Ordinal => {
            const doy = try parseExactNDigits(u16, string, idx_ptr, 3);
            if (doy == 0) return FormatError.InvalidFormat;
            if (doy > 365 + @as(u16, @intFromBool(cal.isLeapYear(fields.year)))) return FormatError.InvalidFormat;
            const date = cal.rdToDate(cal.dateToRD(.{ .year = fields.year, .month = 1, .day = 1 }) + doy - 1);
            fields.month = @truncate(date.month);
            fields.day = @truncate(date.day);
            break :parsing;
        },
        .Month => {
            fields.month = try parseExactNDigits(u8, string, idx_ptr, 2);
            if (idx_ptr.* >= string.len) break :parsing;
            continue :parsing .Day;
        },
        .Day => {
            if (string[idx_ptr.*] == '-') idx_ptr.* += 1; // opt. m-d separator
            fields.day = try parseExactNDigits(u8, string, idx_ptr, 2);
            if (idx_ptr.* >= string.len) break :parsing;
            continue :parsing .DateTimeSep;
        },
        .DateTimeSep => {
            if (!(string[idx_ptr.*] == 'T' or string[idx_ptr.*] == ' ')) {
                return FormatError.InvalidFormat;
            }
            idx_ptr.* += 1;
            if (idx_ptr.* >= string.len) break :parsing;
            continue :parsing .Hour;
        },
        .Hour => {
            fields.hour = try parseExactNDigits(u8, string, idx_ptr, 2);
            if (idx_ptr.* >= string.len) break :parsing;
            continue :parsing .Minute;
        },
        .Minute => {
            if (string[idx_ptr.*] == ':') idx_ptr.* += 1; // opt. h:m separator
            fields.minute = try parseExactNDigits(u8, string, idx_ptr, 2);
            // next might be offset, but not fraction
            if (peekChar(string, idx_ptr)) |c| {
                if (c == '+' or c == '-' or c == 'Z') {
                    continue :parsing .Offset;
                }
            }
            if (idx_ptr.* >= string.len) break :parsing;
            continue :parsing .Second;
        },
        .Second => {
            if (string[idx_ptr.*] == ':') idx_ptr.* += 1; // opt. m:s separator
            fields.second = try parseExactNDigits(u8, string, idx_ptr, 2);
            // next might be offset or fraction
            if (peekChar(string, idx_ptr)) |c| {
                if (c == '+' or c == '-' or c == 'Z') {
                    continue :parsing .Offset;
                }
                if (c == '.' or c == ',') {
                    idx_ptr.* += 1;
                    continue :parsing .Fraction;
                }
            }
            break :parsing;
        },
        .Fraction => {
            const tmp_idx = idx_ptr.*;
            fields.nanosecond = try parseDigits(u32, string, idx_ptr, 9);
            const missing = 9 - (idx_ptr.* - tmp_idx);
            const f: u32 = try std.math.powi(u32, 10, @as(u32, @intCast(missing)));
            fields.nanosecond *= f;
            if (peekChar(string, idx_ptr)) |c| {
                if (c == '+' or c == '-' or c == 'Z') {
                    continue :parsing .Offset;
                }
            }
            break :parsing;
        },
        .Offset => {
            const utcoffset = try parseOffset(i32, string, idx_ptr, 9);
            if (string[idx_ptr.* - 1] == 'Z')
                fields.tz_options = .{ .utc_offset = UTCoffset.UTC }
            else
                fields.tz_options = .{ .utc_offset = try UTCoffset.fromSeconds(utcoffset, "", false) };
            break :parsing;
        },
    }

    return fields;
}

fn peekChar(string: []const u8, idx_ptr: *usize) ?u8 {
    if (idx_ptr.* >= string.len) return null;
    return string[idx_ptr.*];
}

test "peek" {
    const string: []const u8 = "text";
    var idx: usize = 3;
    var peek = peekChar(string, &idx);
    try testing.expectEqual(peek.?, 't');
    idx = 4;
    peek = peekChar(string, &idx);
    try testing.expectEqual(peek, null);
}

// -----
// helpers for %a %A %b %B
// ----->
const sz_abbr: usize = 32;
const sz_normal: usize = 64;

// Get the abbreviated day name in the current locale
fn getDayNameAbbr(n: u8) FormatError![sz_abbr]u8 {
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getDayNameAbbr_(n),
        .windows => windows_specific.getDayNameAbbr_(n),
        else => return FormatError.UnsupportedOS,
    };
}

// Get the day name in the current locale
fn getDayName(n: u8) FormatError![sz_normal]u8 {
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getDayName_(n),
        .windows => windows_specific.getDayName_(n),
        else => return FormatError.UnsupportedOS,
    };
}

// Get the abbreviated month name in the current locale
fn getMonthNameAbbr(n: u8) FormatError![sz_abbr]u8 {
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getMonthNameAbbr_(n),
        .windows => windows_specific.getMonthNameAbbr_(n),
        else => return FormatError.UnsupportedOS,
    };
}

// Get the month name in the current locale
fn getMonthName(n: u8) FormatError![sz_normal]u8 {
    return switch (builtin.os.tag) {
        .linux, .macos => unix_specific.getMonthName_(n),
        .windows => windows_specific.getMonthName_(n),
        else => return FormatError.UnsupportedOS,
    };
}

// since locale-specific names might change at runtime,
// we need to obtain them at runtime.

fn allDayNames() FormatError![7][sz_normal]u8 {
    var result: [7][sz_normal]u8 = undefined;
    for (result, 0..) |_, i| result[i] = try getDayName(@truncate(i));
    return result;
}

fn allDayNamesEng() [7][sz_normal]u8 {
    return [7][sz_normal]u8{
        [6]u8{ 'S', 'u', 'n', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 6]u8),
        [6]u8{ 'M', 'o', 'n', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 6]u8),
        [7]u8{ 'T', 'u', 'e', 's', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 7]u8),
        [9]u8{ 'W', 'e', 'd', 'n', 'e', 's', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 9]u8),
        [8]u8{ 'T', 'h', 'u', 'r', 's', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 8]u8),
        [6]u8{ 'F', 'r', 'i', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 6]u8),
        [8]u8{ 'S', 'a', 't', 'u', 'r', 'd', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 8]u8),
    };
}

fn allDayNamesShort() FormatError![7][sz_abbr]u8 {
    var result: [7][sz_abbr]u8 = undefined;
    for (result, 0..) |_, i| result[i] = try getDayNameAbbr(@truncate(i));
    return result;
}

fn allDayNamesShortEng() [7][sz_abbr]u8 {
    return [7][sz_abbr]u8{
        [3]u8{ 'S', 'u', 'n' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'M', 'o', 'n' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'T', 'u', 'e' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'W', 'e', 'd' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'T', 'h', 'u' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'F', 'r', 'i' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'S', 'a', 't' } ++ std.mem.zeroes([sz_abbr - 3]u8),
    };
}

fn allMonthNames() FormatError![12][sz_normal]u8 {
    var result: [12][sz_normal]u8 = undefined;
    for (result, 0..) |_, i| result[i] = try getMonthName(@truncate(i));
    return result;
}

fn allMonthNamesEng() [12][sz_normal]u8 {
    return [12][sz_normal]u8{
        [7]u8{ 'J', 'a', 'n', 'u', 'a', 'r', 'y' } ++ std.mem.zeroes([sz_normal - 7]u8),
        [8]u8{ 'F', 'e', 'b', 'r', 'u', 'a', 'r', 'y' } ++ std.mem.zeroes([sz_normal - 8]u8),
        [5]u8{ 'M', 'a', 'r', 'c', 'h' } ++ std.mem.zeroes([sz_normal - 5]u8),
        [5]u8{ 'A', 'p', 'r', 'i', 'l' } ++ std.mem.zeroes([sz_normal - 5]u8),
        [3]u8{ 'M', 'a', 'y' } ++ std.mem.zeroes([sz_normal - 3]u8),
        [4]u8{ 'J', 'u', 'n', 'e' } ++ std.mem.zeroes([sz_normal - 4]u8),
        [4]u8{ 'J', 'u', 'l', 'y' } ++ std.mem.zeroes([sz_normal - 4]u8),
        [6]u8{ 'A', 'u', 'g', 'u', 's', 't' } ++ std.mem.zeroes([sz_normal - 6]u8),
        [9]u8{ 'S', 'e', 'p', 't', 'e', 'm', 'b', 'e', 'r' } ++ std.mem.zeroes([sz_normal - 9]u8),
        [7]u8{ 'O', 'c', 't', 'o', 'b', 'e', 'r' } ++ std.mem.zeroes([sz_normal - 7]u8),
        [8]u8{ 'N', 'o', 'v', 'e', 'm', 'b', 'e', 'r' } ++ std.mem.zeroes([sz_normal - 8]u8),
        [8]u8{ 'D', 'e', 'c', 'e', 'm', 'b', 'e', 'r' } ++ std.mem.zeroes([sz_normal - 8]u8),
    };
}

fn allMonthNamesShort() FormatError![12][sz_abbr]u8 {
    var result: [12][sz_abbr]u8 = undefined;
    for (result, 0..) |_, i| result[i] = try getMonthNameAbbr(@truncate(i));
    return result;
}

fn allMonthNamesShortEng() [12][sz_abbr]u8 {
    return [12][sz_abbr]u8{
        [3]u8{ 'J', 'a', 'n' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'F', 'e', 'b' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'M', 'a', 'r' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'A', 'p', 'r' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'M', 'a', 'y' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'J', 'u', 'n' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'J', 'u', 'l' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'A', 'u', 'g' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'S', 'e', 'p' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'O', 'c', 't' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'N', 'o', 'v' } ++ std.mem.zeroes([sz_abbr - 3]u8),
        [3]u8{ 'D', 'e', 'c' } ++ std.mem.zeroes([sz_abbr - 3]u8),
    };
}

test "all names" {
    const dnames = try allDayNames();
    for (dnames) |n| {
        try testing.expect(n[0] != '?'); // '?' is default if error
        try testing.expect(n[1] != 0); // assume at least 2 characters
    }
    const dnames_short = try allDayNamesShort();
    for (dnames_short) |n| {
        try testing.expect(n[0] != '?');
        try testing.expect(n[1] != 0);
    }
    const mnames = try allMonthNames();
    for (mnames) |n| {
        try testing.expect(n[0] != '?');
        try testing.expect(n[1] != 0);
    }
    const mnames_short = try allMonthNamesShort();
    for (mnames_short) |n| {
        try testing.expect(n[0] != '?');
        try testing.expect(n[1] != 0);
    }
}

fn parseDayName(string: []const u8, idx_ptr: *usize, allNames: *const [7][sz_normal]u8) FormatError!u8 {
    var daynum: u8 = 0;
    while (daynum < 7) : (daynum += 1) {
        if (strStartswith(string, idx_ptr, std.mem.sliceTo(&allNames[daynum], 0)))
            return daynum;
    }
    return FormatError.InvalidFormat;
}

fn parseDayNameAbbr(string: []const u8, idx_ptr: *usize, allNames: *const [7][sz_abbr]u8) FormatError!u8 {
    var daynum: u8 = 0;
    while (daynum < 7) : (daynum += 1) {
        if (strStartswith(string, idx_ptr, std.mem.sliceTo(&allNames[daynum], 0)))
            return daynum;
    }
    return FormatError.InvalidFormat;
}

fn parseMonthName(string: []const u8, idx_ptr: *usize, allNames: *const [12][sz_normal]u8) FormatError!u8 {
    var monthnum: u8 = 0;
    while (monthnum < 12) : (monthnum += 1) {
        if (strStartswith(string, idx_ptr, std.mem.sliceTo(&allNames[monthnum], 0)))
            return monthnum + 1;
    }
    return FormatError.InvalidFormat;
}

fn parseMonthNameAbbr(string: []const u8, idx_ptr: *usize, allNames: *const [12][sz_abbr]u8) FormatError!u8 {
    var monthnum: u8 = 0;
    while (monthnum < 12) : (monthnum += 1) {
        if (strStartswith(string, idx_ptr, std.mem.sliceTo(&allNames[monthnum], 0)))
            return monthnum + 1;
    }
    return FormatError.InvalidFormat;
}

test "day / month name in string to day / month number" {
    var idx: usize = 8;
    const string = "...text Monday Tue December Mar text...";
    const dnames = try allDayNames();
    const dnamesShort = try allDayNamesShort();
    const mnames = try allMonthNames();
    const mnamesShort = try allMonthNamesShort();

    var n = try parseDayName(string, &idx, &dnames);
    try testing.expectEqual(1, n);
    idx += 1;

    n = try parseDayNameAbbr(string, &idx, &dnamesShort);
    try testing.expectEqual(2, n);
    idx += 1;

    n = try parseMonthName(string, &idx, &mnames);
    try testing.expectEqual(12, n);
    idx += 1;

    n = try parseMonthNameAbbr(string, &idx, &mnamesShort);
    try testing.expectEqual(3, n);
}

/// Look if 'string' starts with the characters from 'target', beginning at idx.
/// Advance idx by target.len characters if true.
///
/// An empty input to 'string' or 'target' is considered false, which is
/// different to what std.mem.startsWith returns.
fn strStartswith(string: []const u8, idx_ptr: *usize, target: []const u8) bool {
    if (string.len == 0 or target.len == 0) return false;
    if (idx_ptr.* >= string.len) return false;
    const result = std.mem.startsWith(u8, string[idx_ptr.*..], target);
    if (result) idx_ptr.* += target.len;
    return result;
}

test "custom starts with" {
    const string = "some text";
    var idx: usize = 0;
    try testing.expect(!strStartswith(string, &idx, ""));
    try testing.expectEqual(0, idx);
    try testing.expect(!strStartswith(string, &idx, "no"));
    try testing.expectEqual(0, idx);
    try testing.expect(strStartswith(string, &idx, "some"));
    try testing.expectEqual(4, idx);
    try testing.expect(strStartswith(string, &idx, " te"));
    try testing.expectEqual(7, idx);
    idx = 10;
    try testing.expect(!strStartswith(string, &idx, ""));
}
