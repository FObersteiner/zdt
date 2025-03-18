//! Parser for RFC 9636 TZif files, <https://www.rfc-editor.org/rfc/rfc9636>.
//!
//! taken from Zig standard library, 0.12.0-dev.2059+42389cb9c, modified.

const std = @import("std");
const builtin = @import("builtin");

const magic_cookie = "TZif";
const footer_buf_sz: usize = 128;

pub const Transition = struct {
    ts: i64,
    timetype: *Timetype,
};

pub const Timetype = struct {
    offset: i32,
    flags: u8,
    name_data: [6:0]u8,

    pub fn abbreviation(tt: *Timetype) []const u8 {
        return std.mem.sliceTo(tt.name_data[0..], 0);
    }

    pub fn isDst(tt: Timetype) bool {
        return (tt.flags & 0x01) > 0;
    }

    pub fn standardTimeIndicator(tt: Timetype) bool {
        return (tt.flags & 0x02) > 0;
    }

    pub fn utIndicator(tt: Timetype) bool {
        return (tt.flags & 0x04) > 0;
    }
};

pub const Tz = struct {
    allocator: std.mem.Allocator,
    transitions: []const Transition, // TODO : determine max. size required; how to handle less-than-max elements?
    timetypes: []const Timetype, // TODO : determine max. size required; how to handle less-than-max elements?
    footer: ?[]const u8, // TODO: might need to change type if no allocator.dupe available

    const Header = extern struct {
        magic: [4]u8,
        version: u8,
        reserved: [15]u8,
        counts: extern struct {
            isutcnt: u32,
            isstdcnt: u32,
            leapcnt: u32,
            timecnt: u32,
            typecnt: u32,
            charcnt: u32,
        },
    };

    /// Parse a IANA db TZif file. Only accepts version 2 or 3 files.
    pub fn parse(allocator: std.mem.Allocator, reader: anytype) !Tz {
        var legacy_header = try reader.readStruct(Header);
        if (!std.mem.eql(u8, &legacy_header.magic, "TZif")) return error.BadHeader;
        if (legacy_header.version != 0 and legacy_header.version != '2' and legacy_header.version != '3') return error.BadVersion;

        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big) {
            std.mem.byteSwapAllFields(@TypeOf(legacy_header.counts), &legacy_header.counts);
        }

        if (legacy_header.version == 0)
            return parseBlock(allocator, reader, legacy_header, true);

        // If the format is modern, just skip over the legacy data
        const skipv = (legacy_header.counts.timecnt * 5 +
            legacy_header.counts.typecnt * 6 +
            legacy_header.counts.charcnt +
            legacy_header.counts.leapcnt * 8 +
            legacy_header.counts.isstdcnt +
            legacy_header.counts.isutcnt //
        );
        try reader.skipBytes(skipv, .{});

        var header = try reader.readStruct(Header);
        if (!std.mem.eql(u8, &header.magic, magic_cookie)) return error.BadHeader;
        if (header.version != '2' and header.version != '3') return error.BadVersion;
        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big) {
            std.mem.byteSwapAllFields(@TypeOf(header.counts), &header.counts);
        }

        return parseBlock(allocator, reader, header, false);
    }

    fn parseBlock(allocator: std.mem.Allocator, reader: anytype, header: Header, legacy: bool) !Tz {
        if (header.counts.isstdcnt != 0 and header.counts.isstdcnt != header.counts.typecnt) return error.Malformed; // RFC 9636: isstdcnt [...] MUST either be zero or equal to "typecnt"
        if (header.counts.isutcnt != 0 and header.counts.isutcnt != header.counts.typecnt) return error.Malformed; // RFC 9636: isutcnt [...] MUST either be zero or equal to "typecnt"
        if (header.counts.typecnt == 0) return error.Malformed; // RFC 9636: typecnt [...] MUST NOT be zero
        if (header.counts.charcnt == 0) return error.Malformed; // RFC 9636: charcnt [...] MUST NOT be zero
        if (header.counts.charcnt > 256 + 6) return error.Malformed; // Not explicitly banned by RFC 9636 but nonsensical

        // var leapseconds = try allocator.alloc(Leapsecond, header.counts.leapcnt);
        // errdefer allocator.free(leapseconds);
        var transitions = try allocator.alloc(Transition, header.counts.timecnt);
        errdefer allocator.free(transitions);
        var timetypes = try allocator.alloc(Timetype, header.counts.typecnt);
        errdefer allocator.free(timetypes);

        // Parse transition types
        var i: usize = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            transitions[i].ts = if (legacy) try reader.readInt(i32, .big) else try reader.readInt(i64, .big);
        }

        i = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            const tt = try reader.readByte();
            if (tt >= timetypes.len) return error.Malformed; // RFC 9636: Each type index MUST be in the range [0, "typecnt" - 1]
            transitions[i].timetype = &timetypes[tt];
        }

        // Parse time types
        i = 0;
        while (i < header.counts.typecnt) : (i += 1) {
            const offset = try reader.readInt(i32, .big);
            if (offset < -2147483648) return error.Malformed; // RFC 9636: utoff [...] MUST NOT be -2**31
            const dst = try reader.readByte();
            if (dst != 0 and dst != 1) return error.Malformed; // RFC 9636: (is)dst [...] The value MUST be 0 or 1.
            const idx = try reader.readByte();
            if (idx > header.counts.charcnt - 1) return error.Malformed; // RFC 9636: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]
            timetypes[i] = .{ .offset = offset, .flags = dst, .name_data = undefined };

            // Temporarily cache idx in name_data to be processed after we've read the designator names below
            timetypes[i].name_data[0] = idx;
        }

        var designators_data: [256 + 6]u8 = undefined; // TODO : why 256 + 6 ?
        try reader.readNoEof(designators_data[0..header.counts.charcnt]);
        const designators = designators_data[0..header.counts.charcnt];
        if (designators[designators.len - 1] != 0) return error.Malformed; // RFC 9636: charcnt [...] includes the trailing NUL (0x00) octet

        // Iterate through the timetypes again, setting the designator names
        for (timetypes) |*tt| {
            const name = std.mem.sliceTo(designators[tt.name_data[0]..], 0);
            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            // RFC 9636: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters:
            if (name.len > 6) return error.Malformed;
            @memcpy(tt.name_data[0..name.len], name);
            tt.name_data[name.len] = 0;
        }

        // Skip leap seconds / correction since those are not time-zone specific;
        // zdt provides this timezone-independent
        // - move file pointer by header.counts.leapcount * 12
        try reader.skipBytes(@as(u64, header.counts.leapcnt * 12), .{});

        // Parse standard/wall indicators
        i = 0;
        while (i < header.counts.isstdcnt) : (i += 1) {
            const stdtime = try reader.readByte();
            if (stdtime == 1) {
                timetypes[i].flags |= 0x02;
            }
        }

        // Parse UT/local indicators
        i = 0;
        while (i < header.counts.isutcnt) : (i += 1) {
            const ut = try reader.readByte();
            if (ut == 1) {
                timetypes[i].flags |= 0x04;
                // RFC 9636: standard/wall value MUST be one (1) if the UT/local value is one (1):
                if (!timetypes[i].standardTimeIndicator()) return error.Malformed;
            }
        }

        // Footer
        var footer: ?[]u8 = null;
        if (!legacy) {
            if ((try reader.readByte()) != '\n') return error.Malformed; // An RFC 9636 footer must start with a newline
            var footerdata_buf: [footer_buf_sz]u8 = undefined;
            const footer_mem = reader.readUntilDelimiter(&footerdata_buf, '\n') catch |err| switch (err) {
                error.StreamTooLong => return error.OverlargeFooter, // Read more than 128 bytes, much larger than any reasonable POSIX TZ string
                else => return err,
            };
            if (footer_mem.len != 0) {
                // TODO : without allocator, footer might better be a u8[x:0] ?
                footer = try allocator.dupe(u8, footer_mem);
            }
        }
        errdefer if (footer) |ft| allocator.free(ft);

        return Tz{
            .allocator = allocator,
            .transitions = transitions,
            .timetypes = timetypes,
            .footer = footer,
        };
    }

    pub fn deinit(tz: *Tz) void {
        if (tz.footer) |footer| {
            tz.allocator.free(footer);
            tz.footer = null;
        }
        tz.allocator.free(tz.transitions);
        tz.allocator.free(tz.timetypes);

        // set emtpy slices to prevent a segfault if the tz is used after deinit
        tz.transitions = &.{};
        tz.timetypes = &.{Timetype{ .offset = 0, .flags = 0, .name_data = [6:0]u8{ 0, 0, 0, 0, 0, 0 } }};
    }
};

test "slim" {
    const data = @embedFile("./tzif_testdata/asia_tokyo.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 9);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "JDT"));
    try std.testing.expectEqual(tz.transitions[5].ts, -620298000); // 1950-05-06 15:00:00 UTC
}

test "fat" {
    const data = @embedFile("./tzif_testdata/antarctica_davis.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 8);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "+05"));
    try std.testing.expectEqual(tz.transitions[4].ts, 1268251224); // 2010-03-10 20:00:00 UTC
}

test "legacy" {
    // Taken from Slackware 8.0, from 2001
    const data = @embedFile("./tzif_testdata/europe_vatican.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 170);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[69].timetype.name(), "CET"));
    try std.testing.expectEqual(tz.transitions[123].ts, 1414285200); // 2014-10-26 01:00:00 UTC
}
