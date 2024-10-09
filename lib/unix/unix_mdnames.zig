const std = @import("std");
const log = std.log.scoped(.zdt__stringIO_windows);
const c_langinfo = @cImport(@cInclude("langinfo.h"));

const sz_abbr: usize = 32;
const sz_normal: usize = 64;

pub fn getDayNameAbbr_(n: u8) [sz_abbr]u8 {
    const str = std.mem.span(c_langinfo.nl_langinfo(day_names_abbr[n]));
    var result: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    result[0] = '?';
    if (str.len > sz_abbr) return result;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        result[i] = str[i];
    }
    return result;
}

pub fn getDayName_(n: u8) [sz_normal]u8 {
    const str = std.mem.span(c_langinfo.nl_langinfo(day_names[n]));
    var result: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    result[0] = '?';
    if (str.len > sz_normal) return result;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        result[i] = str[i];
    }
    return result;
}

pub fn getMonthNameAbbr_(n: u8) [sz_abbr]u8 {
    const str = std.mem.span(c_langinfo.nl_langinfo(month_names_abbr[n]));
    var result: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    result[0] = '?';
    if (str.len > sz_abbr) return result;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        result[i] = str[i];
    }
    return result;
}

pub fn getMonthName_(n: u8) [sz_normal]u8 {
    const str = std.mem.span(c_langinfo.nl_langinfo(month_names[n]));
    var result: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    result[0] = '?';
    if (str.len > sz_normal) return result;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        result[i] = str[i];
    }
    return result;
}

// abbreviated day name; for %a
const day_names_abbr = [7]c_int{
    c_langinfo.ABDAY_1,
    c_langinfo.ABDAY_2,
    c_langinfo.ABDAY_3,
    c_langinfo.ABDAY_4,
    c_langinfo.ABDAY_5,
    c_langinfo.ABDAY_6,
    c_langinfo.ABDAY_7,
};

// day name; for %A
const day_names = [7]c_int{
    c_langinfo.DAY_1,
    c_langinfo.DAY_2,
    c_langinfo.DAY_3,
    c_langinfo.DAY_4,
    c_langinfo.DAY_5,
    c_langinfo.DAY_6,
    c_langinfo.DAY_7,
};

// abbreviated month name; for %b
const month_names_abbr = [12]c_int{
    c_langinfo.ABMON_1,
    c_langinfo.ABMON_2,
    c_langinfo.ABMON_3,
    c_langinfo.ABMON_4,
    c_langinfo.ABMON_5,
    c_langinfo.ABMON_6,
    c_langinfo.ABMON_7,
    c_langinfo.ABMON_8,
    c_langinfo.ABMON_9,
    c_langinfo.ABMON_10,
    c_langinfo.ABMON_11,
    c_langinfo.ABMON_12,
};

// abbreviated month name; for %B
const month_names = [12]c_int{
    c_langinfo.MON_1,
    c_langinfo.MON_2,
    c_langinfo.MON_3,
    c_langinfo.MON_4,
    c_langinfo.MON_5,
    c_langinfo.MON_6,
    c_langinfo.MON_7,
    c_langinfo.MON_8,
    c_langinfo.MON_9,
    c_langinfo.MON_10,
    c_langinfo.MON_11,
    c_langinfo.MON_12,
};
