//! conversion between datetime and string representation

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const log = std.log.scoped(.zdt__stringIO);

const Datetime = @import("./Datetime.zig");
const cal = @import("./calendar.zig");
const Tz = @import("./Timezone.zig");
const ZdtError = @import("./errors.zig").ZdtError;
const FormatError = @import("./errors.zig").FormatError;
const unix_specific = @import("./unix/unix_mdnames.zig");
const windows_specific = @import("./windows/windows_mdnames.zig");

const TokenizerState = enum(u8) {
    ExpectChar,
    ExpectDirectiveOrModifier,
    ProcessChar,
    ProcessDirective,
    // Finalize, // Zig 0.14 version
};

const token_start: u8 = '%';
const modifier: u8 = ':';

/// Tokenize the parsing directives and parse the datetime string accordingly.
pub fn tokenizeAndParse(data: []const u8, directives: []const u8) !Datetime {
    var fmt_idx: usize = 0;
    var data_idx: usize = 0;
    var am_pm_flags: u8 = 0; // bits; 0 - am, 1 - pm, 2 - found %I
    var fields = Datetime.Fields{};

    // Zig 0.13 :
    var state = TokenizerState.ExpectChar;
    tokenize: while (fmt_idx < directives.len) {
        switch (state) {
            .ExpectChar => {
                if (directives[fmt_idx] == token_start) {
                    fmt_idx += 1;
                    state = .ExpectDirectiveOrModifier;
                    continue :tokenize;
                }
                state = .ProcessChar;
                continue :tokenize;
            },
            .ExpectDirectiveOrModifier => {
                if (directives[fmt_idx] == token_start) { // special case: literal 'token_start'
                    state = .ProcessChar;
                    continue :tokenize;
                }
                state = .ProcessDirective;
                continue :tokenize;
            },
            .ProcessChar => {
                if (data[data_idx] != directives[fmt_idx]) return error.InvalidFormat;
                data_idx += 1;
                fmt_idx += 1;
                if (data_idx >= data.len) break :tokenize;
                state = .ExpectChar;
                continue :tokenize;
            },
            .ProcessDirective => {
                try parseIntoFields(&fields, data, directives[fmt_idx], &data_idx, &am_pm_flags);
                fmt_idx += 1;
                state = .ExpectChar;
                continue :tokenize;
            },
        }
    }
    if (data_idx != data.len) return error.InvalidFormat;
    switch (am_pm_flags) {
        0b000 => {}, // neither %I nor am/pm in input string
        0b101 => fields.hour = fields.hour % 12, //  %I and 'am'
        0b110 => fields.hour = fields.hour % 12 + 12, //  %I and 'pm'
        else => return error.InvalidFormat, // might be %I but no %p or vice versa
    }

    // // Zig 0.14+ :
    // tokenize: switch (TokenizerState.ExpectChar) {
    //     TokenizerState.ExpectChar => {
    //         if (directives[fmt_idx] == token_start) {
    //             fmt_idx += 1;
    //             if (fmt_idx >= directives.len) return error.InvalidFormat;
    //             continue :tokenize .ExpectDirectiveOrModifier;
    //         }
    //         continue :tokenize .ProcessChar;
    //     },
    //     TokenizerState.ExpectDirectiveOrModifier => {
    //         if (directives[fmt_idx] == token_start) { // special case: literal 'token_start'
    //             continue :tokenize .ProcessChar;
    //         }
    //         continue :tokenize .ProcessDirective;
    //     },
    //     TokenizerState.ProcessChar => {
    //         if (data[data_idx] != directives[fmt_idx]) return error.InvalidFormat;
    //         data_idx += 1;
    //         fmt_idx += 1;
    //         if ((data_idx >= data.len) or (fmt_idx >= directives.len)) continue :tokenize .Finalize;
    //         continue :tokenize .ExpectChar;
    //     },
    //     TokenizerState.ProcessDirective => {
    //         try parseIntoFields(&fields, data, directives[fmt_idx], &data_idx, &am_pm_flags);
    //         fmt_idx += 1;
    //         if (fmt_idx >= directives.len) continue :tokenize .Finalize;
    //         continue :tokenize .ExpectChar;
    //     },
    //     TokenizerState.Finalize => {
    //         if (fmt_idx != directives.len) return error.InvalidDirective;
    //         if (data_idx != data.len) return error.InvalidFormat;
    //         switch (am_pm_flags) {
    //             0b000 => {}, // neither %I nor am/pm in input string
    //             0b101 => fields.hour = fields.hour % 12, //  %I and 'am'
    //             0b110 => fields.hour = fields.hour % 12 + 12, //  %I and 'pm'
    //             else => return error.InvalidFormat, // might be %I but no %p or vice versa
    //         }
    //         break :tokenize;
    //     },
    // }

    return try Datetime.fromFields(fields);
}

/// Tokenize the formatting directives and print to the writer interface.
pub fn tokenizeAndPrint(dt: *const Datetime, directives: []const u8, writer: anytype) !void {
    var fmt_idx: usize = 0;
    var mod: usize = 0;

    // Zig 0.13 :
    var state = TokenizerState.ExpectChar;
    tokenize: while (fmt_idx < directives.len) {
        switch (state) {
            .ExpectChar => {
                if (directives[fmt_idx] == token_start) {
                    fmt_idx += 1;
                    state = .ExpectDirectiveOrModifier;
                    continue :tokenize;
                }
                state = .ProcessChar;
                continue :tokenize;
            },
            .ExpectDirectiveOrModifier => {
                if (directives[fmt_idx] == modifier) {
                    mod += 1;
                    fmt_idx += 1;
                    state = .ExpectDirectiveOrModifier;
                    continue :tokenize;
                }
                state = .ProcessDirective;
                continue :tokenize;
            },
            .ProcessChar => {
                try writer.print("{c}", .{directives[fmt_idx]});
                fmt_idx += 1;
                state = .ExpectChar;
                continue :tokenize;
            },
            .ProcessDirective => {
                try printIntoWriter(dt, directives[fmt_idx], mod, writer);
                mod = 0;
                fmt_idx += 1;
                state = .ExpectChar;
                continue :tokenize;
            },
        }
    }

    // // zig 0.14+ :
    // tokenize: switch (TokenizerState.ExpectChar) {
    //     TokenizerState.ExpectChar => {
    //         if (directives[fmt_idx] == token_start) {
    //             fmt_idx += 1;
    //             if (fmt_idx >= directives.len) return error.InvalidFormat;
    //             continue :tokenize .ExpectDirectiveOrModifier;
    //         }
    //         continue :tokenize .ProcessChar;
    //     },
    //     TokenizerState.ExpectDirectiveOrModifier => {
    //         if (directives[fmt_idx] == modifier) {
    //             mod += 1;
    //             fmt_idx += 1;
    //             if (fmt_idx >= directives.len) continue :tokenize .Finalize;
    //             continue :tokenize .ExpectDirectiveOrModifier;
    //         }
    //         continue :tokenize .ProcessDirective;
    //     },
    //     TokenizerState.ProcessChar => {
    //         try writer.print("{c}", .{directives[fmt_idx]});
    //         fmt_idx += 1;
    //         if (fmt_idx >= directives.len) continue :tokenize .Finalize;
    //         continue :tokenize .ExpectChar;
    //     },
    //     TokenizerState.ProcessDirective => {
    //         try printIntoWriter(dt, directives[fmt_idx], mod, writer);
    //         mod = 0;
    //         fmt_idx += 1;
    //         if (fmt_idx >= directives.len) continue :tokenize .Finalize;
    //         continue :tokenize .ExpectChar;
    //     },
    //     TokenizerState.Finalize => {
    //         if (fmt_idx != directives.len) return error.InvalidDirective;
    //         break :tokenize;
    //     },
    // }
}

/// The function that actually fills datetime fields with data.
fn parseIntoFields(
    fields: *Datetime.Fields,
    string: []const u8,
    directive: u8,
    idx_ptr: *usize,
    am_pm_flags: *u8,
) !void {
    switch (directive) {
        'd' => fields.day = try parseDigits(u8, string, idx_ptr, 2),
        // 'e' - use 'd'
        // 'a', // locale-specific, day name short
        // 'A', // locale-specific, day name
        'm' => fields.month = try parseDigits(u8, string, idx_ptr, 2),
        // 'b', // locale-specific, month name short
        // 'B', // locale-specific, month name
        'Y' => fields.year = try parseDigits(u16, string, idx_ptr, 4),
        'y' => fields.year = try parseDigits(u16, string, idx_ptr, 2) + Datetime.century,
        // 'C', - formatting-only
        // 'G',
        'H' => fields.hour = try parseDigits(u8, string, idx_ptr, 2),
        // 'k' - use 'H'
        'I' => fields.hour = blk: { // must be in [1..12]
            const h = try parseDigits(u8, string, idx_ptr, 2);
            am_pm_flags.* |= 4;
            if (h >= 1 and h <= 12) break :blk h else return error.InvalidFormat;
        },
        'P' => am_pm_flags.* |= try parseAmPm(string, idx_ptr),
        'p' => am_pm_flags.* |= try parseAmPm(string, idx_ptr),
        'M' => fields.minute = try parseDigits(u8, string, idx_ptr, 2),
        'S' => fields.second = try parseDigits(u8, string, idx_ptr, 2),
        'f' => {
            // if we only parse n digits out of 9, we have to multiply the result by
            // 10^n to get nanoseconds
            const tmp_idx = idx_ptr.*;
            fields.nanosecond = try parseDigits(u32, string, idx_ptr, 9);
            const missing = 9 - (idx_ptr.* - tmp_idx);
            const f: u32 = std.math.powi(u32, 10, @as(u32, @intCast(missing))) catch
                return error.InvalidFraction;
            fields.nanosecond *= f;
        },
        'z' => { // UTC offset (+|-)hh[:mm[:ss]] or Z
            const utcoffset = try parseOffset(i32, string, idx_ptr, 9);
            if (string[idx_ptr.* - 1] == 'Z')
                fields.tzinfo = Tz.UTC
            else
                fields.tzinfo = try Tz.fromOffset(utcoffset, "");
        },
        // 'Z', - ambiguous!
        // 'i', - IANA identifer; would require allocator
        'j' => {
            const doy = try parseDigits(u16, string, idx_ptr, 3);
            if (doy == 0) return error.InvalidFormat;
            if (doy > 365 + @as(u16, @intFromBool(cal.isLeapYear(fields.year)))) return error.InvalidFormat;
            const date = cal.rdToDate(cal.dateToRD([3]u16{ fields.year, 1, 1 }) + doy - 1);
            fields.month = @truncate(date[1]);
            fields.day = @truncate(date[2]);
        },
        // 'w',
        // 'u',
        // 'W',
        // 'U',
        // 'V',
        'T' => {
            fields.* = try parseISO8601(string, idx_ptr);
        },
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
        else => return error.InvalidDirective,
    }
}

/// The function that actually prints to the writer interface.
fn printIntoWriter(
    dt: *const Datetime,
    directive: u8,
    mod: usize,
    writer: anytype,
) !void {
    switch (directive) {
        'd' => try writer.print("{d:0>2}", .{dt.day}),
        'e' => try writer.print("{d: >2}", .{dt.day}),
        'a' => {
            switch (mod) {
                0 => try writer.print("{s}", .{std.mem.sliceTo(getDayNameAbbr(dt.weekdayNumber())[0..], 0)}), // locale-specific, day name short
                1 => try writer.print("{s}", .{dt.weekday().shortName()}),
                else => return error.InvalidFormat,
            }
        },
        'A' => {
            switch (mod) {
                0 => try writer.print("{s}", .{std.mem.sliceTo(getDayName(dt.weekdayNumber())[0..], 0)}), // locale-specific, day name
                1 => try writer.print("{s}", .{dt.weekday().longName()}),
                else => return error.InvalidFormat,
            }
        },
        'm' => try writer.print("{d:0>2}", .{dt.month}),
        'b' => {
            switch (mod) {
                0 => try writer.print("{s}", .{std.mem.sliceTo(getMonthNameAbbr(dt.month - 1)[0..], 0)}), // locale-specific, month name short
                1 => try writer.print("{s}", .{dt.monthEnum().shortName()}),
                else => return error.InvalidFormat,
            }
        },
        'B' => {
            switch (mod) {
                0 => try writer.print("{s}", .{std.mem.sliceTo(getMonthName(dt.month - 1)[0..], 0)}), // locale-specific, month name
                1 => try writer.print("{s}", .{dt.monthEnum().longName()}),
                else => return error.InvalidFormat,
            }
        },
        'Y' => try writer.print("{d:0>4}", .{dt.year}),
        'y' => try writer.print("{d:0>2}", .{dt.year % 100}),
        'C' => try writer.print("{d:0>2}", .{dt.year / 100}),
        'G' => try writer.print("{d:0>4}", .{dt.toISOCalendar().isoyear}),
        'H' => try writer.print("{d:0>2}", .{dt.hour}),
        'k' => try writer.print("{d: >2}", .{dt.hour}),
        'I' => try writer.print("{d:0>2}", .{twelve_hour_format(dt.hour)}),
        'P' => try writer.print("{s}", .{if (dt.hour < 12) "AM" else "PM"}),
        'p' => try writer.print("{s}", .{if (dt.hour < 12) "am" else "pm"}),
        'M' => try writer.print("{d:0>2}", .{dt.minute}),
        'S' => try writer.print("{d:0>2}", .{dt.second}),
        'f' => {
            switch (mod) {
                0 => try writer.print("{d:0>9}", .{dt.nanosecond}),
                1 => try writer.print("{d:0>3}", .{dt.nanosecond / 1000000}),
                2 => try writer.print("{d:0>6}", .{dt.nanosecond / 1000}),
                else => return error.InvalidFormat,
            }
        },
        'z' => blk: {
            if (dt.isNaive()) break :blk;
            switch (mod) {
                0 => try dt.formatOffset(.{ .fill = 0, .precision = 1 }, writer), // 'z' +0100
                1 => try dt.formatOffset(.{ .fill = ':', .precision = 1 }, writer), // 'z:' +01:00
                2 => try dt.formatOffset(.{ .fill = ':', .precision = 2 }, writer), // 'z::' +01:00:00
                3 => try dt.formatOffset(.{ .fill = ':', .precision = 0 }, writer), // 'z:::' +01
                else => return error.InvalidFormat,
            }
        },
        'Z' => blk: {
            if (dt.isNaive()) break :blk;
            switch (mod) {
                0 => try writer.print("{s}", .{@constCast(&dt.tzinfo.?).abbreviation()}),
                1 => {
                    if (std.meta.eql(dt.tzinfo.?, Tz.UTC))
                        try writer.print("{s}", .{@constCast(&dt.tzinfo.?).name()})
                    else
                        try writer.print("{s}", .{@constCast(&dt.tzinfo.?).abbreviation()});
                },
                else => return error.InvalidFormat,
            }
        },
        'i' => blk: {
            if (dt.isNaive()) break :blk;
            try writer.print("{s}", .{@constCast(&dt.tzinfo.?).name()});
        },
        'j' => try writer.print("{d:0>3}", .{dt.dayOfYear()}),
        'w' => try writer.print("{d}", .{dt.weekdayNumber()}),
        'u' => try writer.print("{d}", .{dt.weekdayIsoNumber()}),
        'W' => try writer.print("{d:0>2}", .{dt.weekOfYearMon()}),
        'U' => try writer.print("{d:0>2}", .{dt.weekOfYearSun()}),
        'V' => try writer.print("{d:0>2}", .{dt.toISOCalendar().isoweek}),
        'T' => try dt.format("", .{}, writer),
        't' => try writer.print("{s}", .{dt.toISOCalendar()}),
        // 'x', // locale-specific, date
        // 'X', // locale-specific, time
        // 'c', // locale-specific, datetime
        's' => try writer.print("{d}", .{dt.unix_sec}),
        '%' => try writer.print("%", .{}),
        else => return error.InvalidDirective,
    }
}

fn parseDigits(comptime T: type, string: []const u8, idx_ptr: *usize, maxDigits: usize) !T {
    const start_idx = idx_ptr.*;
    if (!std.ascii.isDigit(string[start_idx])) return error.InvalidFormat;

    idx_ptr.* += 1;
    while (idx_ptr.* < string.len and // check first if string depleted
        idx_ptr.* < start_idx + maxDigits and
        std.ascii.isDigit(string[idx_ptr.*])) : (idx_ptr.* += 1)
    {}

    return try std.fmt.parseInt(T, string[start_idx..idx_ptr.*], 10);
}

// AM or PM string, no matter if upper or lower case.
fn parseAmPm(string: []const u8, idx_ptr: *usize) !u8 {
    if (idx_ptr.* + 2 > string.len) return error.InvalidFormat;

    var flag: u8 = 0;
    flag = switch (std.ascii.toLower(string[idx_ptr.*])) {
        'a' => 1,
        'p' => 2,
        else => return error.InvalidFormat,
    };

    idx_ptr.* += 1;
    if (std.ascii.toLower(string[idx_ptr.*]) != 'm') return error.InvalidFormat;

    idx_ptr.* += 1;
    return flag;
}

// Turn 24 hour clock into 12 hour clock.
fn twelve_hour_format(hour: u8) u8 {
    return if (hour == 0 or hour == 12) 12 else hour % 12;
}

// Offset UTC in the from of (+|-)hh[:mm[:ss]] or Z.
fn parseOffset(comptime T: type, string: []const u8, idx_ptr: *usize, maxDigits: usize) !T {
    const start_idx = idx_ptr.*;

    var sign: i2 = 1;
    switch (string[start_idx]) {
        '+' => sign = 1,
        '-' => sign = -1,
        'Z' => {
            idx_ptr.* += 1;
            return 0;
        },
        else => return error.InvalidFormat, // must start with sign
    }

    idx_ptr.* += 1;
    while (idx_ptr.* < string.len and // check first if string depleted
        idx_ptr.* < start_idx + maxDigits and
        (std.ascii.isDigit(string[idx_ptr.*]) or string[idx_ptr.*] == ':')) : (idx_ptr.* += 1)
    {}

    // clean offset string:
    var index: usize = 0;
    var offset_chars = [6]u8{ 48, 48, 48, 48, 48, 48 }; // start with 000000;
    for (string[start_idx + 1 .. idx_ptr.*]) |c| { //                  hhmmss
        if (c != ':') {
            offset_chars[index] = c;
            index += 1;
        }
        if (index == 6) break;
    }
    if (index < 2) return error.InvalidFormat; // offset must be at least 2 chars

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

/// Parse ISO8601 formats. The format is infered at runtime.
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
pub fn parseISO8601(string: []const u8, idx_ptr: *usize) !Datetime.Fields {
    var fields = Datetime.Fields{};
    var utcoffset: ?i32 = null;
    var state: ISOParserState = .Year;
    var check_idx: usize = idx_ptr.*;

    parsing: while (idx_ptr.* < string.len) {
        switch (state) {
            .Year => {
                fields.year = try parseDigits(u16, string, idx_ptr, 4);
                if (idx_ptr.* - check_idx != 4) return error.InvalidFormat; // assert 4 digit year
                if (idx_ptr.* == string.len) return error.InvalidFormat; // year-only not allowed
                if (string[idx_ptr.*] == '-') idx_ptr.* += 1; // opt. y-m separator
                state = if (string[idx_ptr.*..].len == 3) .Ordinal else .Month;
                continue :parsing;
            },
            .Ordinal => {
                check_idx = idx_ptr.*;
                const doy = try parseDigits(u16, string, idx_ptr, 3);
                if (idx_ptr.* - check_idx != 3) return error.InvalidFormat; // assert 3 digit ordinal
                if (doy == 0) return error.InvalidFormat;
                if (doy > 365 + @as(u16, @intFromBool(cal.isLeapYear(fields.year)))) return error.InvalidFormat;
                const date = cal.rdToDate(cal.dateToRD([3]u16{ fields.year, 1, 1 }) + doy - 1);
                fields.month = @truncate(date[1]);
                fields.day = @truncate(date[2]);
                break :parsing;
            },
            .Month => {
                check_idx = idx_ptr.*;
                fields.month = try parseDigits(u8, string, idx_ptr, 2);
                if (idx_ptr.* - check_idx != 2) return error.InvalidFormat; // assert 2 digit month
                state = .Day;
                continue :parsing;
            },
            .Day => {
                if (string[idx_ptr.*] == '-') idx_ptr.* += 1; // opt. m-d separator
                check_idx = idx_ptr.*;
                fields.day = try parseDigits(u8, string, idx_ptr, 2);
                if (idx_ptr.* - check_idx != 2) return error.InvalidFormat; // assert 2 digit day
                state = .DateTimeSep;
                continue :parsing;
            },
            .DateTimeSep => {
                if (!(string[idx_ptr.*] == 'T' or string[idx_ptr.*] == ' ')) {
                    return error.InvalidFormat;
                }
                idx_ptr.* += 1;
                state = .Hour;
                continue :parsing;
            },
            .Hour => {
                check_idx = idx_ptr.*;
                fields.hour = try parseDigits(u8, string, idx_ptr, 2);
                if (idx_ptr.* - check_idx != 2) return error.InvalidFormat; // assert 2 digit hour
                state = .Minute;
                continue :parsing;
            },
            .Minute => {
                if (string[idx_ptr.*] == ':') idx_ptr.* += 1; // opt. h:m separator
                check_idx = idx_ptr.*;
                fields.minute = try parseDigits(u8, string, idx_ptr, 2);
                if (idx_ptr.* - check_idx != 2) return error.InvalidFormat; // assert 2 digit minute
                // next might be offset, but not fraction
                if (peekChar(string, idx_ptr)) |c| {
                    if (c == '+' or c == '-' or c == 'Z') {
                        state = .Offset;
                        continue :parsing;
                    }
                }
                state = .Second;
                continue :parsing;
            },
            .Second => {
                if (string[idx_ptr.*] == ':') idx_ptr.* += 1; // opt. m:s separator
                check_idx = idx_ptr.*;
                fields.second = try parseDigits(u8, string, idx_ptr, 2);
                if (idx_ptr.* - check_idx != 2) return error.InvalidFormat; // assert 2 digit second
                // next might be offset or fraction
                if (peekChar(string, idx_ptr)) |c| {
                    if (c == '+' or c == '-' or c == 'Z') {
                        state = .Offset;
                        continue :parsing;
                    }
                    if (c == '.' or c == ',') {
                        idx_ptr.* += 1;
                        state = .Fraction;
                        continue :parsing;
                    }
                }
                break :parsing;
            },
            .Fraction => {
                const tmp_idx = idx_ptr.*;
                fields.nanosecond = try parseDigits(u32, string, idx_ptr, 9);
                const missing = 9 - (idx_ptr.* - tmp_idx);
                const f: u32 = std.math.powi(u32, 10, @as(u32, @intCast(missing))) catch return error.InvalidFraction;
                fields.nanosecond *= f;
                if (peekChar(string, idx_ptr)) |c| {
                    if (c == '+' or c == '-' or c == 'Z') {
                        state = .Offset;
                        continue :parsing;
                    }
                }
                break :parsing;
            },
            .Offset => {
                utcoffset = try parseOffset(i32, string, idx_ptr, 9);
                break :parsing;
            },
        }
    }

    if (utcoffset != null) {
        if (string[idx_ptr.* - 1] == 'Z')
            fields.tzinfo = Tz.UTC
        else
            fields.tzinfo = try Tz.fromOffset(utcoffset.?, "");
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
