const std = @import("std");
const unicode = std.unicode;
const log = std.log.scoped(.zdt__string_windows);
const winnls = @cImport(@cInclude("winnls.h"));

const sz_abbr: usize = 32;
const sz_normal: usize = 64;

pub fn getDayNameAbbr_(n: u8) [sz_abbr]u8 {
    var result: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    result[0] = '?';

    var buf: [sz_abbr / 2]c_ushort = undefined; // u16
    const code = winnls.GetLocaleInfoEx(
        null, // TODO : following consts fail: winnls.LOCALE_NAME_SYSTEM_DEFAULT // winnls.LOCALE_NAME_USER_DEFAULT - why?
        day_names_abbr[n],
        &buf,
        sz_abbr / 2,
    );
    if (code <= 0) return result;

    // Windows UTF-16 LE ("WTF") to UTF-8:
    var arr: [sz_abbr]u8 = undefined;
    // TODO : this could maybe be put into 'result' directly?
    const utf8 = arr[0 .. sz_abbr - 1];
    const n_bytes = unicode.utf16LeToUtf8(utf8, std.mem.sliceTo(buf[0..], 0)) catch 0;

    if (n_bytes == 0) return result;
    if (n_bytes > sz_abbr) return result;
    std.mem.copyForwards(u8, result[0..utf8.len], utf8);

    return result;
}

pub fn getDayName_(n: u8) [sz_normal]u8 {
    var result: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    result[0] = '?';

    var buf: [sz_normal / 2]c_ushort = undefined; // u16
    const code = winnls.GetLocaleInfoEx(
        null,
        day_names[n],
        &buf,
        sz_normal / 2,
    );
    if (code <= 0) return result;

    var arr: [sz_normal]u8 = undefined;
    const utf8 = arr[0 .. sz_normal - 1];
    const n_bytes = unicode.utf16LeToUtf8(utf8, std.mem.sliceTo(buf[0..], 0)) catch 0;

    if (n_bytes == 0) return result;
    if (n_bytes > sz_normal) return result;
    std.mem.copyForwards(u8, result[0..utf8.len], utf8);

    return result;
}

pub fn getMonthNameAbbr_(n: u8) [sz_abbr]u8 {
    var result: [sz_abbr]u8 = std.mem.zeroes([sz_abbr]u8);
    result[0] = '?';

    var buf: [sz_abbr / 2]c_ushort = undefined; // u16
    const code = winnls.GetLocaleInfoEx(
        null,
        month_names_abbr[n],
        &buf,
        sz_abbr / 2,
    );
    if (code <= 0) return result;

    var arr: [sz_abbr]u8 = undefined;
    const utf8 = arr[0 .. sz_abbr - 1];
    const n_bytes = unicode.utf16LeToUtf8(utf8, std.mem.sliceTo(buf[0..], 0)) catch 0;

    if (n_bytes == 0) return result;
    if (n_bytes > sz_abbr) return result;
    std.mem.copyForwards(u8, result[0..utf8.len], utf8);

    return result;
}

pub fn getMonthName_(n: u8) [sz_normal]u8 {
    var result: [sz_normal]u8 = std.mem.zeroes([sz_normal]u8);
    result[0] = '?';

    var buf: [sz_normal / 2]c_ushort = undefined; // u16
    const code = winnls.GetLocaleInfoEx(
        null,
        month_names[n],
        &buf,
        sz_normal / 2,
    );
    if (code <= 0) return result;

    var arr: [sz_normal]u8 = undefined;
    const utf8 = arr[0 .. sz_normal - 1];
    const n_bytes = unicode.utf16LeToUtf8(utf8, std.mem.sliceTo(buf[0..], 0)) catch 0;

    if (n_bytes == 0) return result;
    if (n_bytes > sz_normal) return result;
    std.mem.copyForwards(u8, result[0..utf8.len], utf8);

    return result;
}

// abbreviated day name; for %a
const day_names_abbr = [7]c_ulong{
    winnls.LOCALE_SABBREVDAYNAME7,
    winnls.LOCALE_SABBREVDAYNAME1, // Windows uses Mon as first day of week
    winnls.LOCALE_SABBREVDAYNAME2,
    winnls.LOCALE_SABBREVDAYNAME3,
    winnls.LOCALE_SABBREVDAYNAME4,
    winnls.LOCALE_SABBREVDAYNAME5,
    winnls.LOCALE_SABBREVDAYNAME6,
};

// day name; for %A
const day_names = [7]c_ulong{
    winnls.LOCALE_SDAYNAME7,
    winnls.LOCALE_SDAYNAME1, // Windows uses Mon as first day of week
    winnls.LOCALE_SDAYNAME2,
    winnls.LOCALE_SDAYNAME3,
    winnls.LOCALE_SDAYNAME4,
    winnls.LOCALE_SDAYNAME5,
    winnls.LOCALE_SDAYNAME6,
};

// abbreviated month name; for %b
const month_names_abbr = [12]c_ulong{
    winnls.LOCALE_SABBREVMONTHNAME1,
    winnls.LOCALE_SABBREVMONTHNAME2,
    winnls.LOCALE_SABBREVMONTHNAME3,
    winnls.LOCALE_SABBREVMONTHNAME4,
    winnls.LOCALE_SABBREVMONTHNAME5,
    winnls.LOCALE_SABBREVMONTHNAME6,
    winnls.LOCALE_SABBREVMONTHNAME7,
    winnls.LOCALE_SABBREVMONTHNAME8,
    winnls.LOCALE_SABBREVMONTHNAME9,
    winnls.LOCALE_SABBREVMONTHNAME10,
    winnls.LOCALE_SABBREVMONTHNAME11,
    winnls.LOCALE_SABBREVMONTHNAME12,
};

// abbreviated month name; for %B
const month_names = [12]c_ulong{
    winnls.LOCALE_SMONTHNAME1,
    winnls.LOCALE_SMONTHNAME2,
    winnls.LOCALE_SMONTHNAME3,
    winnls.LOCALE_SMONTHNAME4,
    winnls.LOCALE_SMONTHNAME5,
    winnls.LOCALE_SMONTHNAME6,
    winnls.LOCALE_SMONTHNAME7,
    winnls.LOCALE_SMONTHNAME8,
    winnls.LOCALE_SMONTHNAME9,
    winnls.LOCALE_SMONTHNAME10,
    winnls.LOCALE_SMONTHNAME11,
    winnls.LOCALE_SMONTHNAME12,
};
