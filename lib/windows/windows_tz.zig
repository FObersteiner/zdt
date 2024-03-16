const std = @import("std");
const trnsl = std.zig.c_translation;
const win = @cImport(@cInclude("windows.h")); // TODO: could potentially live without this since I'm already re-declaring RegGetValueA...
const WINAPI: std.builtin.CallingConvention = if (@import("builtin").cpu.arch == .x86) .Stdcall else .C;

const iana_names = @import("./windows_tznames.zig").iana_names;
const windows_names = @import("./windows_tznames.zig").windows_names;
const WinTzError = @import("../errors.zig").WinTzError;

const log = std.log.scoped(.zdt__windows_tz);

const struct_HKEY__ = extern struct { unused: c_int = std.mem.zeroes(c_int) };
const HKEY = ?*align(1) struct_HKEY__;

const HKEY_LOCAL_MACHINE = trnsl.cast(HKEY, //
    trnsl.cast(win.ULONG_PTR, //
    trnsl.cast(win.LONG, //
    trnsl.promoteIntLiteral( //
    c_int,
    0x80000002,
    .hex,
))));

extern fn RegGetValueA(
    hkey: ?*align(1) struct_HKEY__,
    lpSubKey: win.LPCSTR,
    lpValue: win.LPCSTR,
    dwFlags: win.DWORD,
    pdwType: win.LPDWORD,
    pvData: win.PVOID,
    pcbData: win.LPDWORD,
) callconv(WINAPI) c_long;

/// Get the IANA time zone identifier on Windows.
///
/// Reads registry key "SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation"
/// from HKEY_LOCAL_MACHINE, sub-key "TimeZoneKeyName".
/// Result (Windows tz name) is mapped to a IANA tz db name.
///
/// Returns "?" if no mapping entry is found.
pub fn getTzName() ![]const u8 {
    const key = "SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation";
    const sub_key_tz = "TimeZoneKeyName";
    const sz: usize = 256;
    var data_size: win.DWORD = sz; // @sizeOf(win.DWORD);
    var data_str: [sz]u8 = std.mem.zeroes([sz]u8);

    const result = RegGetValueA(
        HKEY_LOCAL_MACHINE,
        key,
        sub_key_tz,
        win.RRF_RT_DWORD,
        null,
        &data_str,
        &data_size,
    );

    if (result < 0) return WinTzError.ReadRegistryFailed;

    const win_name: []const u8 = std.mem.sliceTo(&data_str, 0);

    std.debug.assert(!std.mem.eql(u8, win_name, ""));

    for (0.., windows_names) |i, name| {
        if (std.mem.eql(u8, name, win_name)) {
            return iana_names[i];
        }
    }

    return "?"; // this will likely fail upstream.
}
