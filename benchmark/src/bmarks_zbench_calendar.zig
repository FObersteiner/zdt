const std = @import("std");
const assert = std.debug.assert;

const config = @import("config.zig");

const zbench = @import("zbench");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// ----- Howard Hinnant's data algorithms:
//
pub fn unixdaysFromDate(ymd: [3]u16) i32 {
    const y = if (ymd[1] <= 2) ymd[0] - 1 else ymd[0];
    const era = y / 400;
    const yoe = (y - era * 400); // [0, 399]
    const doy = (153 * (if (ymd[1] > 2) ymd[1] - 3 else ymd[1] + 9) + 2) / 5 + ymd[2] - 1; // [0, 365]
    const doe: u32 = @as(u32, yoe) * 365 + yoe / 4 - yoe / 100 + doy; // [0, 146096]
    const tmp: i32 = @intCast(@as(u32, era) * 146097 + doe);

    return tmp - 719468;
}

pub fn dateFromUnixdays(unix_days: i32) [3]u16 {
    const z: u32 = @intCast(unix_days + 719468);
    const era = if (z >= 0) z / 146097 else z - 14096;
    const doe = z - era * 146097; // [0, 146096]
    const yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; // [0, 399]
    const doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    const mp = (5 * doy + 2) / 153; // [0, 11]
    const d: u16 = @intCast(doy - (153 * mp + 2) / 5 + 1); // [1, 31]
    const m: u16 = @intCast(if (mp < 10) mp + 3 else mp - 9);
    const y: u16 = @intCast(if (m <= 2) yoe + era * 400 + 1 else yoe + era * 400);

    return [_]u16{ y, m, d };
}

// ----- Neri-Schneider algorithms, Zig translation by @travisstaloch
//
const ERA_OFFSET: i32 = 3670;
const DAYS_IN_ERA: i32 = 146097;
const YEARS_IN_ERA: i32 = 400;
const DAYS_TO_UNIX_EPOCH: i32 = 719468;
const DAY_OFFSET: i32 = ERA_OFFSET * DAYS_IN_ERA + DAYS_TO_UNIX_EPOCH;
const YEAR_OFFSET: i32 = ERA_OFFSET * YEARS_IN_ERA;

pub fn rdToDate(rd: i32) [3]u16 {
    const n0: u32 = @intCast(rd +% DAY_OFFSET);
    // century
    const n1 = 4 * n0 + 3;
    const c = n1 / 146097;
    const r = n1 % 146097;
    // year
    const n2 = r | 3;
    const p: u64 = 2939745 * @as(u64, n2);
    const z: u32 = @truncate(p / (1 << 32));
    const n3: u32 = @truncate((p % (1 << 32)) / 2939745 / 4);
    const j = @intFromBool(n3 >= 306);
    const y1: u32 = 100 * c + z + j;
    // month and day
    const n4 = 2141 * n3 + 197913;
    const m1 = n4 / (1 << 16);
    const d1 = n4 % (1 << 16) / 2141;
    // map
    const y = (@as(i32, @intCast(y1))) -% (YEAR_OFFSET);
    const m = if (j != 0) m1 - 12 else m1;
    const d = d1 + 1;
    return [3]u16{ @intCast(y), @intCast(m), @intCast(d) };
}

pub fn dateToRD(ymd: [3]u16) i32 {
    assert(ymd[1] >= 1);
    assert(ymd[2] >= 1);
    const y1: u32 = @intCast(ymd[0] +% YEAR_OFFSET);
    // map
    const jf: u32 = @intFromBool(ymd[1] < 3);
    const y2 = y1 -% jf;
    const m1 = @as(u32, ymd[1]) + 12 * jf;
    const d1 = @as(u32, ymd[2]) -% 1;
    // century
    const c = y2 / 100;
    // year
    const y3 = 1461 * y2 / 4 - c + c / 4;
    // month
    const m = (979 * m1 - 2919) / 32;
    // result
    const n = y3 +% m +% d1;
    return @as(i32, @intCast(n)) -% DAY_OFFSET;
}

// ----- revised versions, based on the Neri/Schneider paper / C++ version
//
pub const Date = struct {
    year: i32 = 0,
    month: u32 = 0,
    day: u32 = 0,
};

pub const S: u32 = 82;
pub const K: u32 = 719468 + 146097 * S;
pub const L: u32 = 400 * S;

pub fn rdToDateCpp(N_U: i32) Date {
    // Rata die shift
    const N: u32 = @as(u32, @bitCast(N_U)) +% K;

    // Century
    const N_1: u32 = 4 * N + 3;
    const C: u32 = N_1 / 146097;
    const N_C: u32 = (N_1 % 146097) / 4;

    // Year
    const N_2: u32 = 4 * N_C + 3;
    const P_2: u64 = @as(u64, 2939745) * N_2;
    const Z: u32 = @intCast(P_2 / 4294967296);
    const N_Y: u32 = @intCast((P_2 % 4294967296) / 2939745 / 4);
    const Y: u32 = 100 * C + Z;

    // Month and day
    const N_3: u32 = 2141 * N_Y + 197913;
    const M: u32 = N_3 / 65536;
    const D: u32 = (N_3 % 65536) / 2141;

    // Map. (Notice the year correction, including type change.)
    const J: u32 = @intFromBool(N_Y >= 306);
    const Y_G: i32 = @intCast(@as(i32, @bitCast(Y -% L)) + @as(i32, @intCast(J)));
    const M_G: u32 = if (J != 0) M - 12 else M;
    const D_G: u32 = D + 1;

    return .{ .year = Y_G, .month = M_G, .day = D_G };
}

pub fn dateToRDcpp(date: Date) i32 {
    // Map. (Notice the year correction, including type change.)
    const J: u32 = @intFromBool(date.month <= 2);
    const Y: u32 = @as(u32, @bitCast(date.year)) +% L - J;
    const M: u32 = if (J != 0) date.month + 12 else date.month;
    const D: u32 = date.day - 1;
    const C: u32 = Y / 100;

    // Rata die
    const y_star: u32 = 1461 * Y / 4 - C + C / 4;
    const m_star: u32 = (979 * M - 2919) / 32;
    const N: u32 = y_star + m_star + D;

    // Rata die shift
    const N_U: i32 = @as(i32, @bitCast(N)) - K;

    return N_U;
}

// -----

fn benchHinnantDate2RD(_: std.mem.Allocator) void {
    var y: u16 = 1;
    while (y < 10000) : (y += 100) {
        const d = unixdaysFromDate([3]u16{ y, 3, 1 });
        std.mem.doNotOptimizeAway(d);
    }
}

fn benchHinnantRD2Date(_: std.mem.Allocator) void {
    var d: i32 = -10000;
    while (d < 100000) : (d += 1000) {
        const dt = dateFromUnixdays(d);
        std.mem.doNotOptimizeAway(dt);
    }
}

fn benchNeriSchnDate2RD(_: std.mem.Allocator) void {
    var y: u16 = 1;
    while (y < 10000) : (y += 100) {
        const d = dateToRD([3]u16{ y, 3, 1 });
        std.mem.doNotOptimizeAway(d);
    }
}

fn benchNeriSchnDate2RDcpp(_: std.mem.Allocator) void {
    var y: i32 = 1;
    while (y < 10000) : (y += 100) {
        const d = dateToRDcpp(.{ .year = y, .month = 3, .day = 1 });
        std.mem.doNotOptimizeAway(d);
    }
}

fn benchNeriSchnRD2Date(_: std.mem.Allocator) void {
    var d: i32 = -10000;
    while (d < 100000) : (d += 1000) {
        const dt = rdToDate(d);
        std.mem.doNotOptimizeAway(dt);
    }
}

fn benchNeriSchnRD2DateCpp(_: std.mem.Allocator) void {
    var d: i32 = -10000;
    while (d < 100000) : (d += 1000) {
        const dt = rdToDateCpp(d);
        std.mem.doNotOptimizeAway(dt);
    }
}

pub fn run() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer bench.deinit();

    try bench.add("hin date-2-rd", benchHinnantDate2RD, .{ .iterations = config.N });
    try bench.add("ner date-2-rd (trs)", benchNeriSchnDate2RD, .{ .iterations = config.N });
    try bench.add("ner date-2-rd (cpp)", benchNeriSchnDate2RDcpp, .{ .iterations = config.N });

    try bench.add("hin rd-2-date", benchHinnantRD2Date, .{ .iterations = config.N });
    try bench.add("ner rd-2-date (trs)", benchNeriSchnRD2Date, .{ .iterations = config.N });
    try bench.add("ner rd-2-date (cpp)", benchNeriSchnRD2DateCpp, .{ .iterations = config.N });

    try stdout.writeAll("\n");
    try bench.run(stdout);

    std.debug.print("\n", .{});
}
