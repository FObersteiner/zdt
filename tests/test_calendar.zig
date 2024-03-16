//! test calendric calculations from a users's perspective (no internal functionality)
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;

const cal = @import("zdt").calendar;
const Datetime = @import("zdt").Datetime;

test "days_in_month" {
    var d = cal.daysInMonth(2, std.time.epoch.isLeapYear(2020));
    try testing.expect(d == 29);
    d = cal.daysInMonth(2, std.time.epoch.isLeapYear(2023));
    try testing.expect(d == 28);
    d = cal.daysInMonth(12, std.time.epoch.isLeapYear(2023));
    try testing.expect(d == 31);

    // index 0 is a place-holder --------vv
    const DAYS_IN_REGULAR_MONTH = [_]u5{ 30, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    for (DAYS_IN_REGULAR_MONTH[1..], 1..) |m, idx| {
        const x = cal.daysInMonth(@truncate(idx), std.time.epoch.isLeapYear(2021));
        try testing.expect(x == m);
    }
}

test "is_leap_month" {
    try testing.expect(cal.isLeapMonth(1900, 7) == false);
    try testing.expect(cal.isLeapMonth(2000, 3) == false);
    try testing.expect(cal.isLeapMonth(2000, 2) == true);
    try testing.expect(cal.isLeapMonth(2020, 2) == true);
    try testing.expect(cal.isLeapMonth(2022, 2) == false);
}

test "weekday" {
    // How many days to add to y to get to x
    try testing.expect(cal.weekdayDifference(0, 0) == 0);
    try testing.expect(cal.weekdayDifference(6, 5) == 1);
    try testing.expect(cal.weekdayDifference(5, 6) == -1);
    try testing.expect(cal.weekdayDifference(0, 6) == -6);
    try testing.expect(cal.weekdayDifference(6, 0) == 6);
}

test "weekday iso-weekday" {
    var i: i32 = 19732; // 2024-01-10; Wed; wd=3, isowd=3
    while (i < 19732 + 360) : (i += 1) {
        const wd = cal.weekdayFromUnixdays(i);
        var isowd = cal.ISOweekdayFromUnixdays(i);
        if (isowd == 7) isowd -= 7;
        try testing.expectEqual(wd, isowd);
    }
}

test "unix-days_from_ymd" {
    var days = cal.unixdaysFromDate([_]u16{ 1970, 1, 1 });
    var want: i32 = 0;
    try testing.expect(days == want);
    days = cal.dateToRD([_]u16{ 1970, 1, 1 });
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 1969, 12, 27 });
    want = -5;
    try testing.expect(days == want);
    days = cal.dateToRD([_]u16{ 1969, 12, 27 });
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 1, 1, 1 });
    want = -719162;
    try testing.expect(days == want);
    days = cal.dateToRD([_]u16{ 1, 1, 1 });
    try testing.expect(days == want);

    days = cal.unixdaysFromDate([_]u16{ 2023, 10, 23 });
    want = 19653;
    try testing.expect(days == want);
    days = cal.dateToRD([_]u16{ 2023, 10, 23 });
    try testing.expect(days == want);

    // the day may overflow
    days = cal.unixdaysFromDate([_]u16{ 1969, 12, 32 });
    want = 0;
    try testing.expect(days == want);
    days = cal.unixdaysFromDate([_]u16{ 2020, 1, 31 + 29 });
    want = 18321;
    try testing.expect(days == want);
    // month my overflow as well
    days = cal.unixdaysFromDate([_]u16{ 1969, 13, 1 });
    want = 0;
    try testing.expect(days == want);
}

test "ymd_from_unix-days" {
    var date = cal.dateFromUnixdays(0);
    var date_ = cal.rdToDate(0);
    var want = [_]u16{ 1970, 1, 1 };
    try testing.expectEqual(want, date);
    try testing.expectEqual(want, date_);

    date = cal.dateFromUnixdays(-719162);
    date_ = cal.rdToDate(-719162);
    want = [_]u16{ 1, 1, 1 };
    try testing.expectEqual(want, date);
    try testing.expectEqual(want, date_);

    date = cal.dateFromUnixdays(19653);
    date_ = cal.rdToDate(19653);
    want = [_]u16{ 2023, 10, 23 };
    try testing.expectEqual(want, date);
    try testing.expectEqual(want, date_);
}

test "iso weeks in year" {
    var i: u14 = 2000;
    while (i < 2400) : (i += 1) {
        const w = cal.weeksPerYear(i);
        const w_ = cal.weeksPerYear_(try Datetime.fromFields(.{ .year = i }));
        try testing.expectEqual(w, w_);
        // if (w == 53) print("\ny: {d}", .{i});
    }
}

// ---vv--- test generated with Python scripts ---vv---

test "leap correction" {
    var corr: u8 = cal.leapCorrection(0);
    try testing.expectEqual(@as(u8, 10), corr);
    corr = cal.leapCorrection(78796799);
    try testing.expectEqual(@as(u8, 10), corr);
    corr = cal.leapCorrection(78796800);
    try testing.expectEqual(@as(u8, 11), corr);
    corr = cal.leapCorrection(94694399);
    try testing.expectEqual(@as(u8, 11), corr);
    corr = cal.leapCorrection(94694400);
    try testing.expectEqual(@as(u8, 12), corr);
    corr = cal.leapCorrection(126230399);
    try testing.expectEqual(@as(u8, 12), corr);
    corr = cal.leapCorrection(126230400);
    try testing.expectEqual(@as(u8, 13), corr);
    corr = cal.leapCorrection(157766399);
    try testing.expectEqual(@as(u8, 13), corr);
    corr = cal.leapCorrection(157766400);
    try testing.expectEqual(@as(u8, 14), corr);
    corr = cal.leapCorrection(189302399);
    try testing.expectEqual(@as(u8, 14), corr);
    corr = cal.leapCorrection(189302400);
    try testing.expectEqual(@as(u8, 15), corr);
    corr = cal.leapCorrection(220924799);
    try testing.expectEqual(@as(u8, 15), corr);
    corr = cal.leapCorrection(220924800);
    try testing.expectEqual(@as(u8, 16), corr);
    corr = cal.leapCorrection(252460799);
    try testing.expectEqual(@as(u8, 16), corr);
    corr = cal.leapCorrection(252460800);
    try testing.expectEqual(@as(u8, 17), corr);
    corr = cal.leapCorrection(283996799);
    try testing.expectEqual(@as(u8, 17), corr);
    corr = cal.leapCorrection(283996800);
    try testing.expectEqual(@as(u8, 18), corr);
    corr = cal.leapCorrection(315532799);
    try testing.expectEqual(@as(u8, 18), corr);
    corr = cal.leapCorrection(315532800);
    try testing.expectEqual(@as(u8, 19), corr);
    corr = cal.leapCorrection(362793599);
    try testing.expectEqual(@as(u8, 19), corr);
    corr = cal.leapCorrection(362793600);
    try testing.expectEqual(@as(u8, 20), corr);
    corr = cal.leapCorrection(394329599);
    try testing.expectEqual(@as(u8, 20), corr);
    corr = cal.leapCorrection(394329600);
    try testing.expectEqual(@as(u8, 21), corr);
    corr = cal.leapCorrection(425865599);
    try testing.expectEqual(@as(u8, 21), corr);
    corr = cal.leapCorrection(425865600);
    try testing.expectEqual(@as(u8, 22), corr);
    corr = cal.leapCorrection(489023999);
    try testing.expectEqual(@as(u8, 22), corr);
    corr = cal.leapCorrection(489024000);
    try testing.expectEqual(@as(u8, 23), corr);
    corr = cal.leapCorrection(567993599);
    try testing.expectEqual(@as(u8, 23), corr);
    corr = cal.leapCorrection(567993600);
    try testing.expectEqual(@as(u8, 24), corr);
    corr = cal.leapCorrection(631151999);
    try testing.expectEqual(@as(u8, 24), corr);
    corr = cal.leapCorrection(631152000);
    try testing.expectEqual(@as(u8, 25), corr);
    corr = cal.leapCorrection(662687999);
    try testing.expectEqual(@as(u8, 25), corr);
    corr = cal.leapCorrection(662688000);
    try testing.expectEqual(@as(u8, 26), corr);
    corr = cal.leapCorrection(709948799);
    try testing.expectEqual(@as(u8, 26), corr);
    corr = cal.leapCorrection(709948800);
    try testing.expectEqual(@as(u8, 27), corr);
    corr = cal.leapCorrection(741484799);
    try testing.expectEqual(@as(u8, 27), corr);
    corr = cal.leapCorrection(741484800);
    try testing.expectEqual(@as(u8, 28), corr);
    corr = cal.leapCorrection(773020799);
    try testing.expectEqual(@as(u8, 28), corr);
    corr = cal.leapCorrection(773020800);
    try testing.expectEqual(@as(u8, 29), corr);
    corr = cal.leapCorrection(820454399);
    try testing.expectEqual(@as(u8, 29), corr);
    corr = cal.leapCorrection(820454400);
    try testing.expectEqual(@as(u8, 30), corr);
    corr = cal.leapCorrection(867715199);
    try testing.expectEqual(@as(u8, 30), corr);
    corr = cal.leapCorrection(867715200);
    try testing.expectEqual(@as(u8, 31), corr);
    corr = cal.leapCorrection(915148799);
    try testing.expectEqual(@as(u8, 31), corr);
    corr = cal.leapCorrection(915148800);
    try testing.expectEqual(@as(u8, 32), corr);
    corr = cal.leapCorrection(1136073599);
    try testing.expectEqual(@as(u8, 32), corr);
    corr = cal.leapCorrection(1136073600);
    try testing.expectEqual(@as(u8, 33), corr);
    corr = cal.leapCorrection(1230767999);
    try testing.expectEqual(@as(u8, 33), corr);
    corr = cal.leapCorrection(1230768000);
    try testing.expectEqual(@as(u8, 34), corr);
    corr = cal.leapCorrection(1341100799);
    try testing.expectEqual(@as(u8, 34), corr);
    corr = cal.leapCorrection(1341100800);
    try testing.expectEqual(@as(u8, 35), corr);
    corr = cal.leapCorrection(1435708799);
    try testing.expectEqual(@as(u8, 35), corr);
    corr = cal.leapCorrection(1435708800);
    try testing.expectEqual(@as(u8, 36), corr);
    corr = cal.leapCorrection(1483228799);
    try testing.expectEqual(@as(u8, 36), corr);
    corr = cal.leapCorrection(1483228800);
    try testing.expectEqual(@as(u8, 37), corr);
}

test "against Pyhton ordinal" {
    var days_want: i32 = 1962788;
    var days_hin = cal.unixdaysFromDate([_]u16{ 7343, 12, 7 });
    var days_neri = cal.dateToRD([_]u16{ 7343, 12, 7 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    var date_want = [_]u16{ 7343, 12, 7 };
    var date_hin = cal.dateFromUnixdays(1962788);
    var date_neri = cal.rdToDate(1962788);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -252206;
    days_hin = cal.unixdaysFromDate([_]u16{ 1279, 6, 26 });
    days_neri = cal.dateToRD([_]u16{ 1279, 6, 26 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1279, 6, 26 };
    date_hin = cal.dateFromUnixdays(-252206);
    date_neri = cal.rdToDate(-252206);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -614260;
    days_hin = cal.unixdaysFromDate([_]u16{ 288, 3, 19 });
    days_neri = cal.dateToRD([_]u16{ 288, 3, 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 288, 3, 19 };
    date_hin = cal.dateFromUnixdays(-614260);
    date_neri = cal.rdToDate(-614260);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2391126;
    days_hin = cal.unixdaysFromDate([_]u16{ 8516, 9, 6 });
    days_neri = cal.dateToRD([_]u16{ 8516, 9, 6 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8516, 9, 6 };
    date_hin = cal.dateFromUnixdays(2391126);
    date_neri = cal.rdToDate(2391126);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 434394;
    days_hin = cal.unixdaysFromDate([_]u16{ 3159, 5, 2 });
    days_neri = cal.dateToRD([_]u16{ 3159, 5, 2 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3159, 5, 2 };
    date_hin = cal.dateFromUnixdays(434394);
    date_neri = cal.rdToDate(434394);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 307988;
    days_hin = cal.unixdaysFromDate([_]u16{ 2813, 3, 30 });
    days_neri = cal.dateToRD([_]u16{ 2813, 3, 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2813, 3, 30 };
    date_hin = cal.dateFromUnixdays(307988);
    date_neri = cal.rdToDate(307988);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 217051;
    days_hin = cal.unixdaysFromDate([_]u16{ 2564, 4, 7 });
    days_neri = cal.dateToRD([_]u16{ 2564, 4, 7 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2564, 4, 7 };
    date_hin = cal.dateFromUnixdays(217051);
    date_neri = cal.rdToDate(217051);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -133898;
    days_hin = cal.unixdaysFromDate([_]u16{ 1603, 5, 27 });
    days_neri = cal.dateToRD([_]u16{ 1603, 5, 27 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1603, 5, 27 };
    date_hin = cal.dateFromUnixdays(-133898);
    date_neri = cal.rdToDate(-133898);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2369822;
    days_hin = cal.unixdaysFromDate([_]u16{ 8458, 5, 9 });
    days_neri = cal.dateToRD([_]u16{ 8458, 5, 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8458, 5, 9 };
    date_hin = cal.dateFromUnixdays(2369822);
    date_neri = cal.rdToDate(2369822);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -289267;
    days_hin = cal.unixdaysFromDate([_]u16{ 1178, 1, 6 });
    days_neri = cal.dateToRD([_]u16{ 1178, 1, 6 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1178, 1, 6 };
    date_hin = cal.dateFromUnixdays(-289267);
    date_neri = cal.rdToDate(-289267);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2119121;
    days_hin = cal.unixdaysFromDate([_]u16{ 7771, 12, 16 });
    days_neri = cal.dateToRD([_]u16{ 7771, 12, 16 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 7771, 12, 16 };
    date_hin = cal.dateFromUnixdays(2119121);
    date_neri = cal.rdToDate(2119121);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2387423;
    days_hin = cal.unixdaysFromDate([_]u16{ 8506, 7, 18 });
    days_neri = cal.dateToRD([_]u16{ 8506, 7, 18 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8506, 7, 18 };
    date_hin = cal.dateFromUnixdays(2387423);
    date_neri = cal.rdToDate(2387423);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1568271;
    days_hin = cal.unixdaysFromDate([_]u16{ 6263, 10, 13 });
    days_neri = cal.dateToRD([_]u16{ 6263, 10, 13 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6263, 10, 13 };
    date_hin = cal.dateFromUnixdays(1568271);
    date_neri = cal.rdToDate(1568271);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -354515;
    days_hin = cal.unixdaysFromDate([_]u16{ 999, 5, 16 });
    days_neri = cal.dateToRD([_]u16{ 999, 5, 16 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 999, 5, 16 };
    date_hin = cal.dateFromUnixdays(-354515);
    date_neri = cal.rdToDate(-354515);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1757543;
    days_hin = cal.unixdaysFromDate([_]u16{ 6781, 12, 28 });
    days_neri = cal.dateToRD([_]u16{ 6781, 12, 28 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6781, 12, 28 };
    date_hin = cal.dateFromUnixdays(1757543);
    date_neri = cal.rdToDate(1757543);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1050506;
    days_hin = cal.unixdaysFromDate([_]u16{ 4846, 3, 10 });
    days_neri = cal.dateToRD([_]u16{ 4846, 3, 10 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4846, 3, 10 };
    date_hin = cal.dateFromUnixdays(1050506);
    date_neri = cal.rdToDate(1050506);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -585856;
    days_hin = cal.unixdaysFromDate([_]u16{ 365, 12, 25 });
    days_neri = cal.dateToRD([_]u16{ 365, 12, 25 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 365, 12, 25 };
    date_hin = cal.dateFromUnixdays(-585856);
    date_neri = cal.rdToDate(-585856);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -594184;
    days_hin = cal.unixdaysFromDate([_]u16{ 343, 3, 8 });
    days_neri = cal.dateToRD([_]u16{ 343, 3, 8 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 343, 3, 8 };
    date_hin = cal.dateFromUnixdays(-594184);
    date_neri = cal.rdToDate(-594184);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -326176;
    days_hin = cal.unixdaysFromDate([_]u16{ 1076, 12, 17 });
    days_neri = cal.dateToRD([_]u16{ 1076, 12, 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1076, 12, 17 };
    date_hin = cal.dateFromUnixdays(-326176);
    date_neri = cal.rdToDate(-326176);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 197872;
    days_hin = cal.unixdaysFromDate([_]u16{ 2511, 10, 4 });
    days_neri = cal.dateToRD([_]u16{ 2511, 10, 4 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2511, 10, 4 };
    date_hin = cal.dateFromUnixdays(197872);
    date_neri = cal.rdToDate(197872);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 256688;
    days_hin = cal.unixdaysFromDate([_]u16{ 2672, 10, 15 });
    days_neri = cal.dateToRD([_]u16{ 2672, 10, 15 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2672, 10, 15 };
    date_hin = cal.dateFromUnixdays(256688);
    date_neri = cal.rdToDate(256688);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1400451;
    days_hin = cal.unixdaysFromDate([_]u16{ 5804, 4, 22 });
    days_neri = cal.dateToRD([_]u16{ 5804, 4, 22 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 5804, 4, 22 };
    date_hin = cal.dateFromUnixdays(1400451);
    date_neri = cal.rdToDate(1400451);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1805887;
    days_hin = cal.unixdaysFromDate([_]u16{ 6914, 5, 9 });
    days_neri = cal.dateToRD([_]u16{ 6914, 5, 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6914, 5, 9 };
    date_hin = cal.dateFromUnixdays(1805887);
    date_neri = cal.rdToDate(1805887);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -607863;
    days_hin = cal.unixdaysFromDate([_]u16{ 305, 9, 24 });
    days_neri = cal.dateToRD([_]u16{ 305, 9, 24 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 305, 9, 24 };
    date_hin = cal.dateFromUnixdays(-607863);
    date_neri = cal.rdToDate(-607863);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1634870;
    days_hin = cal.unixdaysFromDate([_]u16{ 6446, 2, 14 });
    days_neri = cal.dateToRD([_]u16{ 6446, 2, 14 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6446, 2, 14 };
    date_hin = cal.dateFromUnixdays(1634870);
    date_neri = cal.rdToDate(1634870);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 114823;
    days_hin = cal.unixdaysFromDate([_]u16{ 2284, 5, 17 });
    days_neri = cal.dateToRD([_]u16{ 2284, 5, 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2284, 5, 17 };
    date_hin = cal.dateFromUnixdays(114823);
    date_neri = cal.rdToDate(114823);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2284041;
    days_hin = cal.unixdaysFromDate([_]u16{ 8223, 6, 30 });
    days_neri = cal.dateToRD([_]u16{ 8223, 6, 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8223, 6, 30 };
    date_hin = cal.dateFromUnixdays(2284041);
    date_neri = cal.rdToDate(2284041);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2006650;
    days_hin = cal.unixdaysFromDate([_]u16{ 7464, 1, 9 });
    days_neri = cal.dateToRD([_]u16{ 7464, 1, 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 7464, 1, 9 };
    date_hin = cal.dateFromUnixdays(2006650);
    date_neri = cal.rdToDate(2006650);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2222408;
    days_hin = cal.unixdaysFromDate([_]u16{ 8054, 9, 30 });
    days_neri = cal.dateToRD([_]u16{ 8054, 9, 30 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8054, 9, 30 };
    date_hin = cal.dateFromUnixdays(2222408);
    date_neri = cal.rdToDate(2222408);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1566488;
    days_hin = cal.unixdaysFromDate([_]u16{ 6258, 11, 25 });
    days_neri = cal.dateToRD([_]u16{ 6258, 11, 25 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6258, 11, 25 };
    date_hin = cal.dateFromUnixdays(1566488);
    date_neri = cal.rdToDate(1566488);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1040431;
    days_hin = cal.unixdaysFromDate([_]u16{ 4818, 8, 9 });
    days_neri = cal.dateToRD([_]u16{ 4818, 8, 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4818, 8, 9 };
    date_hin = cal.dateFromUnixdays(1040431);
    date_neri = cal.rdToDate(1040431);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 205432;
    days_hin = cal.unixdaysFromDate([_]u16{ 2532, 6, 15 });
    days_neri = cal.dateToRD([_]u16{ 2532, 6, 15 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2532, 6, 15 };
    date_hin = cal.dateFromUnixdays(205432);
    date_neri = cal.rdToDate(205432);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1164957;
    days_hin = cal.unixdaysFromDate([_]u16{ 5159, 7, 19 });
    days_neri = cal.dateToRD([_]u16{ 5159, 7, 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 5159, 7, 19 };
    date_hin = cal.dateFromUnixdays(1164957);
    date_neri = cal.rdToDate(1164957);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1752397;
    days_hin = cal.unixdaysFromDate([_]u16{ 6767, 11, 26 });
    days_neri = cal.dateToRD([_]u16{ 6767, 11, 26 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 6767, 11, 26 };
    date_hin = cal.dateFromUnixdays(1752397);
    date_neri = cal.rdToDate(1752397);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 447654;
    days_hin = cal.unixdaysFromDate([_]u16{ 3195, 8, 21 });
    days_neri = cal.dateToRD([_]u16{ 3195, 8, 21 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3195, 8, 21 };
    date_hin = cal.dateFromUnixdays(447654);
    date_neri = cal.rdToDate(447654);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2675835;
    days_hin = cal.unixdaysFromDate([_]u16{ 9296, 3, 9 });
    days_neri = cal.dateToRD([_]u16{ 9296, 3, 9 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9296, 3, 9 };
    date_hin = cal.dateFromUnixdays(2675835);
    date_neri = cal.rdToDate(2675835);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2926947;
    days_hin = cal.unixdaysFromDate([_]u16{ 9983, 9, 17 });
    days_neri = cal.dateToRD([_]u16{ 9983, 9, 17 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9983, 9, 17 };
    date_hin = cal.dateFromUnixdays(2926947);
    date_neri = cal.rdToDate(2926947);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -691905;
    days_hin = cal.unixdaysFromDate([_]u16{ 75, 8, 18 });
    days_neri = cal.dateToRD([_]u16{ 75, 8, 18 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 75, 8, 18 };
    date_hin = cal.dateFromUnixdays(-691905);
    date_neri = cal.rdToDate(-691905);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2463506;
    days_hin = cal.unixdaysFromDate([_]u16{ 8714, 11, 8 });
    days_neri = cal.dateToRD([_]u16{ 8714, 11, 8 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8714, 11, 8 };
    date_hin = cal.dateFromUnixdays(2463506);
    date_neri = cal.rdToDate(2463506);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2660688;
    days_hin = cal.unixdaysFromDate([_]u16{ 9254, 9, 19 });
    days_neri = cal.dateToRD([_]u16{ 9254, 9, 19 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 9254, 9, 19 };
    date_hin = cal.dateFromUnixdays(2660688);
    date_neri = cal.rdToDate(2660688);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -49503;
    days_hin = cal.unixdaysFromDate([_]u16{ 1834, 6, 20 });
    days_neri = cal.dateToRD([_]u16{ 1834, 6, 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1834, 6, 20 };
    date_hin = cal.dateFromUnixdays(-49503);
    date_neri = cal.rdToDate(-49503);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2209046;
    days_hin = cal.unixdaysFromDate([_]u16{ 8018, 3, 1 });
    days_neri = cal.dateToRD([_]u16{ 8018, 3, 1 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8018, 3, 1 };
    date_hin = cal.dateFromUnixdays(2209046);
    date_neri = cal.rdToDate(2209046);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 1053411;
    days_hin = cal.unixdaysFromDate([_]u16{ 4854, 2, 21 });
    days_neri = cal.dateToRD([_]u16{ 4854, 2, 21 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 4854, 2, 21 };
    date_hin = cal.dateFromUnixdays(1053411);
    date_neri = cal.rdToDate(1053411);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 707952;
    days_hin = cal.unixdaysFromDate([_]u16{ 3908, 4, 23 });
    days_neri = cal.dateToRD([_]u16{ 3908, 4, 23 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3908, 4, 23 };
    date_hin = cal.dateFromUnixdays(707952);
    date_neri = cal.rdToDate(707952);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 446314;
    days_hin = cal.unixdaysFromDate([_]u16{ 3191, 12, 20 });
    days_neri = cal.dateToRD([_]u16{ 3191, 12, 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3191, 12, 20 };
    date_hin = cal.dateFromUnixdays(446314);
    date_neri = cal.rdToDate(446314);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -67034;
    days_hin = cal.unixdaysFromDate([_]u16{ 1786, 6, 20 });
    days_neri = cal.dateToRD([_]u16{ 1786, 6, 20 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1786, 6, 20 };
    date_hin = cal.dateFromUnixdays(-67034);
    date_neri = cal.rdToDate(-67034);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 183929;
    days_hin = cal.unixdaysFromDate([_]u16{ 2473, 7, 31 });
    days_neri = cal.dateToRD([_]u16{ 2473, 7, 31 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 2473, 7, 31 };
    date_hin = cal.dateFromUnixdays(183929);
    date_neri = cal.rdToDate(183929);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 2483164;
    days_hin = cal.unixdaysFromDate([_]u16{ 8768, 9, 3 });
    days_neri = cal.dateToRD([_]u16{ 8768, 9, 3 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 8768, 9, 3 };
    date_hin = cal.dateFromUnixdays(2483164);
    date_neri = cal.rdToDate(2483164);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = 692617;
    days_hin = cal.unixdaysFromDate([_]u16{ 3866, 4, 28 });
    days_neri = cal.dateToRD([_]u16{ 3866, 4, 28 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 3866, 4, 28 };
    date_hin = cal.dateFromUnixdays(692617);
    date_neri = cal.rdToDate(692617);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);

    days_want = -290462;
    days_hin = cal.unixdaysFromDate([_]u16{ 1174, 9, 29 });
    days_neri = cal.dateToRD([_]u16{ 1174, 9, 29 });
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{ 1174, 9, 29 };
    date_hin = cal.dateFromUnixdays(-290462);
    date_neri = cal.rdToDate(-290462);
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);
}
