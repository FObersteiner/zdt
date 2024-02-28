const std = @import("std");

const iana_names = @import("./windows/windows_tznames.zig").iana_names;
const windows_names = @import("./windows/windows_tznames.zig").windows_names;

const log = std.log.scoped(.zdt__windows_tz);

const WinTzError = @import("./errors.zig").WinTzError;

/// get the IANA time zone identifier on Windows
pub fn getTzName() ![]const u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // TODO : replace shell call with system lib call (or read registry):
    // https://stackoverflow.com/q/16074815/10197418
    // https://stackoverflow.com/q/7062984/10197418
    // https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-gettimezoneinformation
    // Python, via reg key: https://github.com/regebro/tzlocal/blob/master/tzlocal/win32.py#L48
    const argv = [_][]const u8{ "tzutil", "/g" };
    const proc = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = &argv,
    });

    defer allocator.free(proc.stdout);
    defer allocator.free(proc.stderr);

    if (proc.stdout.len == 0) return WinTzError.TzUtilFailed;

    const win_name: []const u8 = proc.stdout;

    for (0.., windows_names) |i, name| {
        if (std.mem.eql(u8, name, win_name)) {
            return iana_names[i];
        }
    }

    return win_name; // this will likely fail further up
}
