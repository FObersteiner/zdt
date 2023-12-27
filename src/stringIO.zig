//! conversion between datetime and string
//! code is heavily inspired by chrono-zig; https://codeberg.org/geemili/chrono-zig
const std = @import("std");
const datetime = @import("datetime.zig");
const tz = @import("timezone.zig");

pub const FormatCode = enum(u8) {
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
pub const Part = union(enum) {
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
pub fn parseFormatBuf(buf: []Part, format_str: []const u8) ![]Part {
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

pub fn parseFormatAlloc(allocator: std.mem.Allocator, format_str: []const u8) ![]Part {
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

pub fn formatDatetimeParts(writer: anytype, parts: []const Part, dt: datetime.Datetime) !void {
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
pub fn parseDatetime(comptime format: []const u8, dtString: []const u8) !datetime.Datetime {
    var year: ?u14 = null;
    var month: ?u4 = null;
    var day: ?u5 = null;
    var hour: ?u5 = null;
    var minute: ?u6 = null;
    var second: ?u6 = null;
    var nanosecond: ?u30 = null;
    var utcoffset: ?i20 = null;

    comptime var next_char_is_specifier = false;
    var dt_string_idx: usize = 0;
    inline for (format) |fc| {
        if (next_char_is_specifier) {
            switch (fc) {
                // Date specifiers
                'Y' => {
                    std.debug.assert(year == null);
                    // Read digits until: 1) there is four digits or 2) the next character is not a digit
                    year = try parseDigits(u14, dtString, &dt_string_idx, 4);
                },
                'm' => {
                    std.debug.assert(month == null);
                    // Read 2 digits or just 1 if the digit after is not a digit
                    month = try parseDigits(u4, dtString, &dt_string_idx, 2);
                },
                'd' => {
                    std.debug.assert(day == null);
                    // Read 2 digits or just 1 if the digit after is not a digit
                    day = try parseDigits(u5, dtString, &dt_string_idx, 2);
                },

                // Time specifiers
                'H' => {
                    std.debug.assert(hour == null);
                    hour = try parseDigits(u5, dtString, &dt_string_idx, 2);
                },
                'M' => {
                    std.debug.assert(minute == null);
                    minute = try parseDigits(u6, dtString, &dt_string_idx, 2);
                },
                'S' => {
                    std.debug.assert(second == null);
                    second = try parseDigits(u6, dtString, &dt_string_idx, 2);
                },
                'f' => {
                    std.debug.assert(nanosecond == null);
                    nanosecond = try parseDigits(u30, dtString, &dt_string_idx, 9);
                },

                // UTC offset (+|-)hh[:mm[:ss]]
                'z' => {
                    std.debug.assert(utcoffset == null);
                    utcoffset = try parseOffset(i20, dtString, &dt_string_idx, 9);
                },

                // literals
                '%' => {
                    if (dtString[dt_string_idx] != fc) {
                        return error.InvalidFormat;
                    }
                    dt_string_idx += 1;
                },

                else => @compileError("Invalid format specifier '" ++ [_]u8{fc} ++ "'"),
            }
            next_char_is_specifier = false;
        } else {
            if (fc == '%') {
                next_char_is_specifier = true;
            } else {
                if (dtString[dt_string_idx] != fc) {
                    return error.InvalidFormat;
                }
                dt_string_idx += 1;
            }
        }
    }

    // if we come here, the string must be completely consumed
    if (dt_string_idx != dtString.len) {
        return error.InvalidFormat;
    }

    var tzinfo = tz.TZ{};
    if (utcoffset != null) {
        try tzinfo.loadOffset(utcoffset.?, "");
    }

    return datetime.Datetime.fromFields(.{
        .year = year orelse 1,
        .month = month orelse 1,
        .day = day orelse 1,
        .hour = hour orelse 0,
        .minute = minute orelse 0,
        .second = second orelse 0,
        .nanosecond = nanosecond orelse 0,
        .tzinfo = if (utcoffset == null) null else tzinfo,
    });
}

// ----- String to Datetime Helpers -----------------

fn parseDigits(comptime T: type, dtString: []const u8, idx: *usize, maxDigits: usize) !T {
    const start_idx = idx.*;
    if (!std.ascii.isDigit(dtString[start_idx])) return error.InvalidFormat;

    idx.* += 1;
    while (idx.* < dtString.len and // check first if dtString depleted
        idx.* < start_idx + maxDigits and
        std.ascii.isDigit(dtString[idx.*])) : (idx.* += 1)
    {}

    return try std.fmt.parseInt(T, dtString[start_idx..idx.*], 10);
}

fn parseOffset(comptime T: type, dtString: []const u8, idx: *usize, maxDigits: usize) !T {
    const start_idx = idx.*;

    var sign: i2 = 1;
    if (dtString[start_idx] == '+') {
        sign = 1;
    } else if (dtString[start_idx] == '-') {
        sign = -1;
    } else {
        return error.InvalidFormat; // must start with sign
    }

    idx.* += 1;
    while (idx.* < dtString.len and // check first if dtString depleted
        idx.* < start_idx + maxDigits and
        (std.ascii.isDigit(dtString[idx.*]) or dtString[idx.*] == ':')) : (idx.* += 1)
    {}

    // clean offset string:
    var index: usize = 0;
    var offset_chars = [6]u8{ 48, 48, 48, 48, 48, 48 }; // start with 0000
    for (dtString[start_idx + 1 .. idx.*]) |c| {
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
