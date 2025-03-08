const std = @import("std");
const trnsl = std.zig.c_translation;

const iana_names = @import("./windows_tznames.zig").iana_names;
const windows_names = @import("./windows_tznames.zig").windows_names;
const WinTzError = @import("../errors.zig").WinTzError;

const log = std.log.scoped(.zdt__windows_tz);

const WINAPI: std.builtin.CallingConvention = if (@import("builtin").cpu.arch == .x86) .Stdcall else .C;
const DWORD = u32;
const LONG = i32;
const LPCSTR = [*c]const u8;
const LPDWORD = [*c]DWORD;
const ULONG_PTR = c_ulonglong;
const PVOID = ?*anyopaque;
const RRF_RT_REG_BINARY = @as(c_int, 0x00000008);
const RRF_RT_REG_DWORD = @as(c_int, 0x00000010);
const RRF_RT_DWORD = RRF_RT_REG_BINARY | RRF_RT_REG_DWORD;

const struct_HKEY__ = extern struct { unused: c_int = std.mem.zeroes(c_int) };
const HKEY = ?*align(1) struct_HKEY__;

const HKEY_LOCAL_MACHINE = trnsl.cast(HKEY, //
    trnsl.cast(ULONG_PTR, //
        trnsl.cast(LONG, //
            trnsl.promoteIntLiteral( //
                c_int,
                0x80000002,
                .hex,
            ))));

// https://learn.microsoft.com/de-de/windows/win32/api/winreg/nf-winreg-reggetvaluea
extern fn RegGetValueA(
    hkey: ?*align(1) struct_HKEY__,
    lpSubKey: LPCSTR,
    lpValue: LPCSTR,
    dwFlags: DWORD,
    pdwType: LPDWORD,
    pvData: PVOID,
    pcbData: LPDWORD,
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
    var data_size: DWORD = sz;
    var data_str: [sz]u8 = std.mem.zeroes([sz]u8);

    const result = RegGetValueA(
        HKEY_LOCAL_MACHINE,
        key,
        sub_key_tz,
        RRF_RT_DWORD,
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
