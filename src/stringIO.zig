//! conversion between datetime and string
//! code is heavily inspired by chrono-zig; https://codeberg.org/geemili/chrono-zig
const std = @import("std");
const datetime = @import("datetime.zig");
const tz = @import("timezone.zig");

/// directives for formatting datetime strings
const FormatCode = enum(u8) {
    year = 'Y',
    month = 'm',
    day = 'd',
    hour = 'H',
    min = 'M',
    sec = 'S',
    nanos = 'f',
    offset = 'z',
    percent_lit = '%',

    pub fn formatDatetime(
        self: FormatCode,
        writer: anytype,
        dt: datetime.Datetime,
    ) !void {
        switch (self) {
            .month => try writer.print("{d:0>2}", .{dt.month}),
            .year => try writer.print("{d}", .{dt.year}),
            .day => try writer.print("{d:0>2}", .{dt.day}),
            .hour => try writer.print("{d:0>2}", .{dt.hour}),
            .min => try writer.print("{d:0>2}", .{dt.minute}),
            .sec => try writer.print("{d:0>2}", .{dt.second}),
            .nanos => try writer.print("{d:0>9}", .{dt.nanosecond}),
            .offset => try dt.formatOffset(writer),
            .percent_lit => try writer.print("%", .{}),
        }
    }
};

// a part of a parsing/formatting directive
const Part = union(enum) {
    literal: u8,
    specifier: FormatCode,

    pub fn formatDatetime(
        self: Part,
        writer: anytype,
        dt: datetime.Datetime,
    ) !void {
        switch (self) {
            .literal => |b| try writer.writeByte(b),
            .specifier => |s| try s.formatDatetime(writer, dt),
        }
    }
};

// parse a string with format codes to a list of Part
fn parseFormatBuf(buf: []Part, format_str: []const u8) ![]Part {
    var parts_idx: usize = 0;

    var next_char_is_specifier = false;
    for (format_str) |fc| {
        if (next_char_is_specifier) {
            if (fc == '%') {
                next_char_is_specifier = false;
                buf[parts_idx] = .{ .literal = fc };
                parts_idx += 1;
                continue;
            }
            buf[parts_idx] = .{
                .specifier = std.meta.intToEnum(FormatCode, fc) catch return error.InvalidSpecifier,
            };
            parts_idx += 1;
            next_char_is_specifier = false;
        } else {
            if (fc == '%') {
                next_char_is_specifier = true;
            } else {
                buf[parts_idx] = .{ .literal = fc };
                parts_idx += 1;
            }
        }
    }

    return buf[0..parts_idx];
}

fn parseFormatAlloc(allocator: std.mem.Allocator, format_str: []const u8) ![]Part {
    var parts = std.ArrayList(Part).init(allocator);
    errdefer parts.deinit();

    var next_char_is_specifier = false;
    for (format_str) |fc| {
        if (next_char_is_specifier) {
            const specifier = std.meta.intToEnum(FormatCode, fc) catch return error.InvalidSpecifier;
            try parts.append(.{ .specifier = specifier });
            next_char_is_specifier = false;
        } else {
            if (fc == '%') {
                next_char_is_specifier = true;
            } else {
                try parts.append(.{ .literal = fc });
            }
        }
    }

    return parts.toOwnedSlice();
}

fn formatDatetimeParts(writer: anytype, parts: []const Part, dt: datetime.Datetime) !void {
    for (parts) |part| {
        try part.formatDatetime(writer, dt);
    }
}

pub fn formatDatetime(writer: anytype, format: []const u8, dt: datetime.Datetime) !void {
    var next_char_is_specifier = false;
    for (format) |fc| {
        if (next_char_is_specifier) {
            const specifier = std.meta.intToEnum(FormatCode, fc) catch return error.InvalidSpecifier;
            try specifier.formatDatetime(writer, dt);
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

/// string to datetime instance, with a compile-time-known format
pub fn parseDatetime(comptime format: []const u8, dt_string: []const u8) !datetime.Datetime {
    var fields = datetime.DatetimeFields{};

    comptime var next_char_is_specifier = false;
    var dt_string_idx: usize = 0;
    inline for (format) |fc| {
        if (next_char_is_specifier) {
            switch (fc) {
                // Date specifiers
                'Y' => fields.year = try parseDigits(u14, dt_string, &dt_string_idx, 4),
                'm' => fields.month = try parseDigits(u7, dt_string, &dt_string_idx, 2),
                'd' => fields.day = try parseDigits(u7, dt_string, &dt_string_idx, 2),
                // Time specifiers
                'H' => fields.hour = try parseDigits(u7, dt_string, &dt_string_idx, 2),
                'M' => fields.minute = try parseDigits(u7, dt_string, &dt_string_idx, 2),
                'S' => fields.second = try parseDigits(u7, dt_string, &dt_string_idx, 2),
                'f' => {
                    // if we only parse n digits out of 9, we have to multiply the result by
                    // 10^n to get nanoseconds
                    const tmp_idx = dt_string_idx;
                    fields.nanosecond = try parseDigits(u30, dt_string, &dt_string_idx, 9);
                    const missing = 9 - (dt_string_idx - tmp_idx);
                    const f: u30 = try std.math.powi(u30, 10, @as(u30, @intCast(missing)));
                    fields.nanosecond *= f;
                },
                // UTC offset (+|-)hh[:mm[:ss]] or Z
                'z' => {
                    const utcoffset = try parseOffset(i20, dt_string, &dt_string_idx, 9);
                    fields.tzinfo = try tz.fromOffset(utcoffset, "");
                    if (dt_string[dt_string_idx - 1] == 'Z') {
                        fields.tzinfo.?.name = "UTC";
                        fields.tzinfo.?.abbreviation = [6:0]u8{ 'Z', 0x00, 0xAA, 0xAA, 0xAA, 0xAA };
                    }
                },
                // literals
                '%' => {
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

    return datetime.Datetime.fromFields(fields);
}

/// Parse ISO8601 formats. Format is infered at runtime.
/// Required is at least a year and a month, separated by ASCII minus.
/// Date and time separator is either 'T' or ASCII space.
///
/// ## examples
///
/// string                         len  datetime, normlized ISO8601
/// -----------------------------|----|------------------------------------
/// 2014-08                        7    2014-08-01T00:00:00
/// 2014-08-23                     10   2014-08-23T00:00:00
/// 2014-08-23 12:15               16   2014-08-23T12:15:00
/// 2014-08-23T12:15:56            19   2014-08-23T12:15:56
/// 2014-08-23T12:15:56.999999999Z 30   2014-08-23T12:15:56.999999999+00:00
/// 2014-08-23 12:15:56+01         22   2014-08-23T12:15:56+01:00
/// 2014-08-23T12:15:56-0530       24   2014-08-23T12:15:56-05:30
/// 2014-08-23T12:15:56+02:15:30   28   2014-08-23T12:15:56+02:15:30
pub fn parseISO8601(dt_string: []const u8) !datetime.Datetime {
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

    var fields = datetime.DatetimeFields{};
    var utcoffset: ?i20 = null;

    var dt_string_idx: usize = 0;
    parseblock: {
        // yyyy-mm
        fields.year = try parseDigits(u14, dt_string, &dt_string_idx, 4);
        if (dt_string_idx != 4) return error.InvalidFormat; // 2-digit year not allowed
        if (dt_string[dt_string_idx] != '-') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.month = try parseDigits(u7, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 7) return error.InvalidFormat; // 1-digit month not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-dd
        if (dt_string[dt_string_idx] != '-') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.day = try parseDigits(u7, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 10) return error.InvalidFormat; // 1-digit day not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM
        if (!(dt_string[dt_string_idx] == 'T' or dt_string[dt_string_idx] == ' ')) return error.InvalidFormat;
        dt_string_idx += 1;
        fields.hour = try parseDigits(u7, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 13) return error.InvalidFormat; // 1-digit hour not allowed
        if (dt_string[dt_string_idx] != ':') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.minute = try parseDigits(u7, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 16) return error.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS
        if (dt_string[dt_string_idx] != ':') return error.InvalidFormat;
        dt_string_idx += 1;
        fields.second = try parseDigits(u7, dt_string, &dt_string_idx, 2);
        if (dt_string_idx != 19) return error.InvalidFormat; // 1-digit minute not allowed
        if (dt_string_idx == dt_string.len) break :parseblock;

        // yyyy-mm-ddTHH:MM:SS[+-](offset or Z)
        if (dt_string[dt_string_idx] == '+' or
            dt_string[dt_string_idx] == '-' or
            dt_string[dt_string_idx] == 'Z')
        {
            utcoffset = try parseOffset(i20, dt_string, &dt_string_idx, 9);
            if (dt_string_idx == dt_string.len) break :parseblock;
            return error.InvalidFormat; // offset must not befollowed by other fields
        }

        // yyyy-mm-ddTHH:MM:SS.fff (fractional seconds separator can either be '.' or ',')
        if (!(dt_string[dt_string_idx] == '.' or dt_string[dt_string_idx] == ',')) return error.InvalidFormat;
        dt_string_idx += 1;
        // parse any number of fractional seconds up to 9
        const tmp_idx = dt_string_idx;
        fields.nanosecond = try parseDigits(u30, dt_string, &dt_string_idx, 9);
        const missing = 9 - (dt_string_idx - tmp_idx);
        const f: u30 = try std.math.powi(u30, 10, @as(u30, @intCast(missing)));
        fields.nanosecond *= f;
        if (dt_string_idx == dt_string.len) break :parseblock;

        // trailing UTC offset
        utcoffset = try parseOffset(i20, dt_string, &dt_string_idx, 9);
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dt_string.len) {
        return error.InvalidFormat;
    }

    if (utcoffset != null) {
        fields.tzinfo = try tz.fromOffset(utcoffset.?, "");
        if (dt_string[dt_string_idx - 1] == 'Z') {
            fields.tzinfo.?.name = "UTC";
            fields.tzinfo.?.abbreviation = [6:0]u8{ 'Z', 0x00, 0xAA, 0xAA, 0xAA, 0xAA };
        }
    }

    return datetime.Datetime.fromFields(fields);
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
    for (dt_string[start_idx + 1 .. idx.*]) |c| { //                   hhmmss
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

const u6Sorter = struct {
    fn cmp(_: void, a: u6, b: u6) std.math.Order {
        return std.math.order(a, b);
    }
};

// --- internal tests

const TestCase = struct {
    string: []const u8,
    dt: datetime.Datetime,
    directive: []const u8 = "",
};

test "format naive datetimes with parts api" {
    const cases = [_]TestCase{
        .{
            .dt = try datetime.Datetime.naiveFromList(.{ 2021, 2, 18, 17, 0, 0, 0 }),
            .string = "2021-02-18 17:00:00",
        },
        .{
            .dt = try datetime.Datetime.naiveFromList(.{ 1970, 1, 1, 0, 0, 0, 0 }),
            .string = "1970-01-01 00:00:00",
        },
    };

    const parts = try parseFormatAlloc(std.testing.allocator, "%Y-%m-%d %H:%M:%S");
    defer std.testing.allocator.free(parts);

    for (cases) |case| {
        var s = std.ArrayList(u8).init(std.testing.allocator);
        defer s.deinit();
        try formatDatetimeParts(s.writer(), parts, case.dt);
        try std.testing.expectEqualStrings(case.string, s.items);
    }
}

test "parse format string" {
    const parts = try parseFormatAlloc(std.testing.allocator, "%Y-%m-%d %H:%M:%S.%f");
    defer std.testing.allocator.free(parts);
    try std.testing.expectEqualSlices(Part, &[_]Part{
        .{ .specifier = .year },
        .{ .literal = '-' },
        .{ .specifier = .month },
        .{ .literal = '-' },
        .{ .specifier = .day },
        .{ .literal = ' ' },
        .{ .specifier = .hour },
        .{ .literal = ':' },
        .{ .specifier = .min },
        .{ .literal = ':' },
        .{ .specifier = .sec },
        .{ .literal = '.' },
        .{ .specifier = .nanos },
    }, parts);
}
