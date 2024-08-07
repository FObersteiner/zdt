import zoneinfo
from pathlib import Path

wd = Path(__file__).parent / ".." / "lib"
zoneinfo_path = "./tzdata/zoneinfo"
dst = wd / "tzdata.zig"

# zoneinfo needs to use zdt zoneinfo
zoneinfo.reset_tzpath(to=((wd / zoneinfo_path).resolve(),))

skip_zones = ("localtime",)  # this might be present if a system zoneinfo is used

with open(dst, "w") as fp:
    print("//! zoneinfo, embedded in a hash map.", file=fp)
    print(
        "//! This file is generated by gen_tzdb_embedding.py, do not edit.\n", file=fp
    )
    print('const std = @import("std");\n', file=fp)
    print("pub const tzdata = std.StaticStringMap([]const u8).initComptime(.{", file=fp)
    for z in sorted(zoneinfo.available_timezones()):
        if z in skip_zones:
            continue
        print(f'    .{{ "{z}", @embedFile("{zoneinfo_path}/{z}") }},', file=fp)
    print(" });", end="", file=fp)

print(f"{dst.resolve().as_posix()} updated.")
