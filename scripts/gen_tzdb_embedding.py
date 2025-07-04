import zoneinfo
import sys
from pathlib import Path
from datetime import datetime, UTC

assert len(sys.argv) == 2, f"need exactly 1 arg, got {len(sys.argv)-1}"
tag = sys.argv[1]

wd = Path(__file__).parent / ".." / "lib"
zoneinfo_path = "./tzdata/zoneinfo"
dst = wd / "tzdata.zig"

# zoneinfo needs to use zdt zoneinfo
zoneinfo.reset_tzpath(to=((wd / zoneinfo_path).resolve(),))

skip_zones = ("localtime",)  # this might be present if a system zoneinfo is used

with open(dst, "w") as fp:
    print("//! zoneinfo, embedded in a hash map.", file=fp)
    print("//! This file is generated by gen_tzdb_embedding.py, do not edit.", file=fp)
    print(f"//! last updated: {datetime.now(UTC).isoformat()}\n", file=fp)

    print('const std = @import("std");\n', file=fp)
    print(
        """pub fn sizeOfTZdata() usize {
    var s: usize = 0;
    for (tzdata.keys()) |zone| {
        if (tzdata.get(zone)) |TZifBytes| s += TZifBytes.len;
    }
    return s;
}\n""",
        file=fp,
    )

    print(f'pub const tzdb_version = "{tag}";\n', file=fp)

    print("pub const tzdata = std.StaticStringMap([]const u8).initComptime(.{", file=fp)
    for z in sorted(zoneinfo.available_timezones()):
        if z in skip_zones:
            continue
        print(f'    .{{ "{z}", @embedFile("{zoneinfo_path}/{z}") }},', file=fp)
    print("});\n", end="", file=fp)

print(f"{dst.resolve().as_posix()} updated.")
