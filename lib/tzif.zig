//! Parsers for RFC 9636 TZif files, <https://www.rfc-editor.org/rfc/rfc9636>.
//!
//! Originally taken from Zig 0.12.0-dev.2059+42389cb9c standard library, modified.

const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const assert = std.debug.assert;
const log = std.log.scoped(.test_tzif);

const TZifReadError = @import("./errors.zig").TZifReadError;

// File header must start with this.
const magic_cookie = "TZif";

// There is a test below to ensure this is sufficient:
const footer_buf_sz: usize = 64;

// This is checked by an assertion:
const desgnation_buf_sz: usize = 64;

// Constants for fixed array sizes of transitions and timetypes.
// The sizes need to be verified for each new version of the tzdb.
const timetypes_buf_sz: usize = 18;
const transitions_buf_sz: usize = 310;

/// A transition to a new timetype
pub const Transition = struct {
    // Unix timestamp when the transition happens:
    ts: i64,
    // Index of the according timetype in the timetype array or slice:
    timetype_idx: usize,
};

/// A specific UTC offset within a timezone. Referenced by a Transition.
pub const Timetype = struct {
    offset: i32,
    flags: u8,
    name_data: [6:0]u8,

    pub fn designation(tt: *const Timetype) []const u8 {
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

/// TZif header struct
const Header = extern struct {
    magic: [4]u8, // must be == magic_cookie
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

/// A time zone specification to be loaded from a TZif file.
/// Requires dynamic allocation of heap memory.
pub const TzAlloc = struct {
    allocator: std.mem.Allocator,
    transitions: []const Transition,
    timetypes: []const Timetype,
    footer: ?[]const u8,

    /// Parse a IANA db TZif file. Only accepts version 2+ files.
    pub fn parse(allocator: std.mem.Allocator, reader: anytype) TZifReadError!TzAlloc {
        var legacy_header = try reader.readStruct(Header);
        if (!std.mem.eql(u8, &legacy_header.magic, "TZif")) return TZifReadError.BadHeader;

        if (legacy_header.version != '2' and legacy_header.version != '3')
            return TZifReadError.BadVersion;

        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big)
            std.mem.byteSwapAllFields(@TypeOf(legacy_header.counts), &legacy_header.counts);

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
        if (!std.mem.eql(u8, &header.magic, magic_cookie)) return TZifReadError.BadHeader;
        if (header.version != '2' and header.version != '3') return TZifReadError.BadVersion;

        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big)
            std.mem.byteSwapAllFields(@TypeOf(header.counts), &header.counts);

        return parseBlock(allocator, reader, header);
    }

    /// Load TZif data itself and make a Tz
    fn parseBlock(allocator: std.mem.Allocator, reader: anytype, header: Header) TZifReadError!TzAlloc {
        // RFC 9636: isstdcnt [...] MUST either be zero or equal to "typecnt":
        if (header.counts.isstdcnt != 0 and header.counts.isstdcnt != header.counts.typecnt)
            return TZifReadError.Malformed;
        // RFC 9636: isutcnt [...] MUST either be zero or equal to "typecnt":
        if (header.counts.isutcnt != 0 and header.counts.isutcnt != header.counts.typecnt)
            return TZifReadError.Malformed;
        if (header.counts.typecnt == 0) return TZifReadError.Malformed; // RFC 9636: typecnt [...] MUST NOT be zero
        if (header.counts.charcnt == 0) return TZifReadError.Malformed; // RFC 9636: charcnt [...] MUST NOT be zero
        if (header.counts.charcnt > 256 + 6) return TZifReadError.Malformed; // Not explicitly banned by RFC 9636 but nonsensical

        var transitions = try allocator.alloc(Transition, header.counts.timecnt);
        errdefer allocator.free(transitions);
        var timetypes = try allocator.alloc(Timetype, header.counts.typecnt);
        errdefer allocator.free(timetypes);

        // Parse transition types
        assert(header.counts.timecnt <= transitions_buf_sz);
        var i: usize = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            transitions[i].ts = try reader.readInt(i64, .big);
        }

        i = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            const tt = try reader.readByte();
            if (tt >= timetypes.len) return TZifReadError.Malformed; // RFC 9636: Each type index MUST be in the range [0, "typecnt" - 1]
            transitions[i].timetype_idx = tt;
        }

        // Parse time types
        assert(header.counts.typecnt <= timetypes_buf_sz);
        i = 0;
        while (i < header.counts.typecnt) : (i += 1) {
            const offset = try reader.readInt(i32, .big);
            if (offset < -2147483648) return TZifReadError.Malformed; // RFC 9636: utoff [...] MUST NOT be -2**31
            const dst = try reader.readByte();
            if (dst != 0 and dst != 1) return TZifReadError.Malformed; // RFC 9636: (is)dst [...] The value MUST be 0 or 1.
            const idx = try reader.readByte();
            if (idx > header.counts.charcnt - 1) return TZifReadError.Malformed; // RFC 9636: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]
            timetypes[i] = .{ .offset = offset, .flags = dst, .name_data = undefined };

            // Temporarily cache idx in name_data to be processed after we've read the designator names below
            timetypes[i].name_data[0] = idx;
        }

        assert(header.counts.charcnt <= desgnation_buf_sz);
        var designators_data: [desgnation_buf_sz]u8 = undefined;
        try reader.readNoEof(designators_data[0..header.counts.charcnt]);
        const designators = designators_data[0..header.counts.charcnt];
        if (designators[designators.len - 1] != 0) return TZifReadError.Malformed; // RFC 9636: charcnt [...] includes the trailing NUL (0x00) octet

        // Iterate through the timetypes again, setting the designator names
        for (timetypes) |*tt| {
            const name = std.mem.sliceTo(designators[tt.name_data[0]..], 0);
            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            // RFC 9636: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters:
            if (name.len > 6) return TZifReadError.Malformed;
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
                if (!timetypes[i].standardTimeIndicator()) return TZifReadError.Malformed;
            }
        }

        // Footer / POSIX TZ string
        var footer: ?[]u8 = null;

        if ((try reader.readByte()) != '\n') return TZifReadError.Malformed; // An RFC 9636 footer must start with a newline
        var footerdata_buf: [footer_buf_sz]u8 = undefined;
        const footer_mem = try reader.readUntilDelimiter(&footerdata_buf, '\n');
        if (footer_mem.len != 0)
            footer = try allocator.dupe(u8, footer_mem);

        errdefer if (footer) |ft| allocator.free(ft);

        return TzAlloc{
            .allocator = allocator,
            .transitions = transitions,
            .timetypes = timetypes,
            .footer = footer,
            // .h = header,
        };
    }

    pub fn deinit(tz: *TzAlloc) void {
        if (tz.footer) |footer| {
            tz.allocator.free(footer);
            tz.footer = null;
        }
        tz.allocator.free(tz.transitions);
        tz.allocator.free(tz.timetypes);

        // Set empty slices to prevent a segfault if the tz is used after deinit.
        // Note that this gives undefiend behavior if the tz is used anyway!
        tz.transitions = &.{};
        tz.timetypes = &.{Timetype{ .offset = 0, .flags = 0, .name_data = [6:0]u8{ 0, 0, 0, 0, 0, 0 } }};
    }
};

//----------------------------------------------------------------------------------------------------

/// TZif data structure that requires no heap memory allocation
pub const Tz = struct {
    n_transitions: usize,
    n_timetypes: usize,
    __transitions_data: [transitions_buf_sz]Transition,
    __timetypes_data: [timetypes_buf_sz]Timetype,
    __footer_data: [footer_buf_sz]u8 = std.mem.zeroes([footer_buf_sz]u8), // newline-terminated

    /// Parse a IANA db TZif file, allocator-free. Only accepts version 2+ files.
    pub fn parse(reader: anytype) TZifReadError!Tz {
        var legacy_header = try reader.readStruct(Header);
        if (!std.mem.eql(u8, &legacy_header.magic, "TZif")) return TZifReadError.BadHeader;

        if (legacy_header.version != '2' and legacy_header.version != '3') return TZifReadError.BadVersion;

        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big) {
            std.mem.byteSwapAllFields(@TypeOf(legacy_header.counts), &legacy_header.counts);
        }

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
        if (!std.mem.eql(u8, &header.magic, magic_cookie)) return TZifReadError.BadHeader;
        if (header.version != '2' and header.version != '3') return TZifReadError.BadVersion;

        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.big)
            std.mem.byteSwapAllFields(@TypeOf(header.counts), &header.counts);

        return parseBlock(reader, header);
    }

    /// Load TZif data itself and make a Tz
    fn parseBlock(reader: anytype, header: Header) TZifReadError!Tz {
        // RFC 9636: isstdcnt [...] MUST either be zero or equal to "typecnt":
        if (header.counts.isstdcnt != 0 and header.counts.isstdcnt != header.counts.typecnt)
            return TZifReadError.Malformed;
        // RFC 9636: isutcnt [...] MUST either be zero or equal to "typecnt":
        if (header.counts.isutcnt != 0 and header.counts.isutcnt != header.counts.typecnt)
            return TZifReadError.Malformed;
        if (header.counts.typecnt == 0) return TZifReadError.Malformed; // RFC 9636: typecnt [...] MUST NOT be zero
        if (header.counts.charcnt == 0) return TZifReadError.Malformed; // RFC 9636: charcnt [...] MUST NOT be zero
        if (header.counts.charcnt > 256 + 6) return TZifReadError.Malformed; // Not explicitly banned by RFC 9636 but nonsensical

        var __footer_data: [footer_buf_sz]u8 = std.mem.zeroes([footer_buf_sz]u8);
        var __timetypes_data: [timetypes_buf_sz]Timetype = undefined;
        var __transitions_data: [transitions_buf_sz]Transition = undefined;

        // Parse transitions.
        assert(header.counts.timecnt <= transitions_buf_sz);
        var i: usize = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            __transitions_data[i].ts = try reader.readInt(i64, .big);
        }

        // Each transition has an index that specifies the according timetype.
        i = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            __transitions_data[i].timetype_idx = try reader.readByte();
        }

        // Parse time types.
        assert(header.counts.typecnt <= timetypes_buf_sz);
        i = 0;
        while (i < header.counts.typecnt) : (i += 1) {
            const offset = try reader.readInt(i32, .big);
            if (offset < -2147483648) return TZifReadError.Malformed; // RFC 9636: utoff [...] MUST NOT be -2**31
            const dst = try reader.readByte();
            if (dst != 0 and dst != 1) return TZifReadError.Malformed; // RFC 9636: (is)dst [...] The value MUST be 0 or 1.
            const idx = try reader.readByte();
            if (idx > header.counts.charcnt - 1) return TZifReadError.Malformed; // RFC 9636: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]
            __timetypes_data[i] = .{ .offset = offset, .flags = dst, .name_data = undefined };
            // Temporarily cache idx in name_data to be processed after we've read the designator names below
            __timetypes_data[i].name_data[0] = idx;
        }

        assert(header.counts.charcnt <= desgnation_buf_sz);
        var designators_data: [desgnation_buf_sz]u8 = undefined;
        try reader.readNoEof(designators_data[0..header.counts.charcnt]);
        const designators = designators_data[0..header.counts.charcnt];
        if (designators[designators.len - 1] != 0) return TZifReadError.Malformed; // RFC 9636: charcnt [...] includes the trailing NUL (0x00) octet

        // Iterate through the timetypes again, setting the designator names
        i = 0;
        while (i < header.counts.typecnt) : (i += 1) {
            const name = std.mem.sliceTo(designators[__timetypes_data[i].name_data[0]..], 0);
            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            // RFC 9636: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters:
            if (name.len > 6) return TZifReadError.Malformed;
            @memcpy(__timetypes_data[i].name_data[0..name.len], name);
            __timetypes_data[i].name_data[name.len] = 0;
        }

        // Skip leap seconds / correction since those are not time-zone specific;
        // zdt provides this timezone-independent.
        //
        // Move file pointer by header.counts.leapcount * 12.
        try reader.skipBytes(@as(u64, header.counts.leapcnt * 12), .{});

        // Parse standard/wall indicators.
        i = 0;
        while (i < header.counts.isstdcnt) : (i += 1) {
            const stdtime = try reader.readByte();
            if (stdtime == 1) {
                __timetypes_data[i].flags |= 0x02;
            }
        }

        // Parse UT/local indicators.
        i = 0;
        while (i < header.counts.isutcnt) : (i += 1) {
            const ut = try reader.readByte();
            if (ut == 1) {
                __timetypes_data[i].flags |= 0x04;
                // RFC 9636: standard/wall value MUST be one (1) if the UT/local value is one (1):
                if (!__timetypes_data[i].standardTimeIndicator()) return TZifReadError.Malformed;
            }
        }

        // Footer / POSIX TZ string.
        if ((try reader.readByte()) != '\n') return TZifReadError.Malformed; // An RFC 9636 footer must start with a newline
        _ = try reader.readUntilDelimiter(&__footer_data, '\n');

        return Tz{
            .n_transitions = header.counts.timecnt,
            .n_timetypes = header.counts.typecnt,
            .__transitions_data = __transitions_data,
            .__timetypes_data = __timetypes_data,
            .__footer_data = __footer_data,
        };
    }
};

//----------------------------------------------------------------------------------------------------

test "slim" {
    const data = @embedFile("./tzif_testdata/asia_tokyo.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try TzAlloc.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 9);
    var tt = tz.timetypes[tz.transitions[3].timetype_idx];
    try std.testing.expect(std.mem.eql(u8, tt.designation(), "JDT"));
    try std.testing.expectEqual(tz.transitions[5].ts, -620298000); // 1950-05-06 15:00:00 UTC
}

test "fat" {
    const data = @embedFile("./tzif_testdata/antarctica_davis.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try TzAlloc.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 8);
    var tt = tz.timetypes[tz.transitions[3].timetype_idx];
    try std.testing.expect(std.mem.eql(u8, tt.designation(), "+05"));
    try std.testing.expectEqual(tz.transitions[4].ts, 1268251224); // 2010-03-10 20:00:00 UTC
}

test "legacy fails" {
    const data = @embedFile("./tzif_testdata/europe_vatican.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    const err = TzAlloc.parse(std.testing.allocator, in_stream.reader());
    try testing.expectError(TZifReadError.BadVersion, err);
}

test "load a lot of TZif" {
    const tzdata = @import("./tzdata.zig").tzdata;
    var sz_footer: usize = 0;
    for (tzdata.keys()) |zone| {
        if (tzdata.get(zone)) |TZifBytes| {
            var in_stream = std.io.fixedBufferStream(TZifBytes);
            var tzif_tz = try TzAlloc.parse(testing.allocator, in_stream.reader());
            defer tzif_tz.deinit();

            if (tzif_tz.footer.?.len > sz_footer) sz_footer = tzif_tz.footer.?.len;

            try in_stream.seekTo(0);
            const tzif_tz_noalloc = try Tz.parse(in_stream.reader());
            const foot = std.mem.sliceTo(tzif_tz_noalloc.__footer_data[0..], '\n');

            try testing.expectEqual(foot.len, tzif_tz.footer.?.len);
            try testing.expectEqual(tzif_tz_noalloc.n_transitions, tzif_tz.transitions.len);
            try testing.expectEqual(tzif_tz_noalloc.n_timetypes, tzif_tz.timetypes.len);
        }
    }
    try testing.expect(sz_footer <= footer_buf_sz);
}
