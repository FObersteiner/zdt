import random
import zoneinfo
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

OPEN_BRACE = "{"
CLOSE_BRACE = "}"
N = 25

# zoneinfo needs to use tz path of the module
zoneinfo.reset_tzpath(
    to=((Path(__file__).parent / ".." / "lib" / "tzdata" / "zoneinfo").resolve(),)
)

dst = (Path(__file__).parent / ".." / "tests" / "test_Timezone.zig").resolve()
search = "// the following test is auto-generated by gen_test_tzones.py. do not edit this line and below.\n"

with open(dst, "r") as fobj:
    content = fobj.readlines()

idx = content.index(search)
assert idx > 0

content = content[: idx + 1]
content.append("\n")

random.seed(9311)

allzones = tuple(zoneinfo.available_timezones())
unixrange = range(-2145920400, 2145913200)

content.append('test "conversion between random time zones" {')

za, zb = random.sample(allzones, 2)
ta, tb = random.sample(unixrange, 2)
dta = datetime.fromtimestamp(ta, tz=ZoneInfo(za))
dtb = datetime.fromtimestamp(tb, tz=ZoneInfo(zb))
s_b = dtb.astimezone(ZoneInfo(za)).isoformat(timespec="seconds")
if s_b.count(":") < 4:
    s_b += ":00"
s_c = dta.astimezone(ZoneInfo(zb)).isoformat(timespec="seconds")
if s_c.count(":") < 4:
    s_c += ":00"
content.append(
    f"""
    var tz_a = try Tz.fromTzdata("{za}", testing.allocator);
    var tz_b = try Tz.fromTzdata("{zb}", testing.allocator);

    var dt_a = try Datetime.fromUnix({ta}, Duration.Resolution.second, .{OPEN_BRACE}.tz=&tz_a{CLOSE_BRACE});
    var dt_b = try Datetime.fromUnix({tb}, Duration.Resolution.second,  .{OPEN_BRACE}.tz=&tz_b{CLOSE_BRACE});
    var dt_c = try dt_a.tzConvert(.{OPEN_BRACE}.tz=&tz_b{CLOSE_BRACE});
    dt_b = try dt_b.tzConvert(.{OPEN_BRACE}.tz=&tz_a{CLOSE_BRACE});

    var s_b = std.ArrayList(u8).init(testing.allocator);
    var s_c = std.ArrayList(u8).init(testing.allocator);
    defer s_b.deinit();
    defer s_c.deinit();

    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("{s_b}", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("{s_c}", s_c.items);

    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();\n"""
)

for _ in range(N):
    za, zb = random.sample(allzones, 2)
    ta, tb = random.sample(unixrange, 2)
    dta = datetime.fromtimestamp(ta, tz=ZoneInfo(za))
    dtb = datetime.fromtimestamp(tb, tz=ZoneInfo(zb))
    s_b = dtb.astimezone(ZoneInfo(za)).isoformat(timespec="seconds")
    if s_b.count(":") < 4:
        s_b += ":00"
    s_c = dta.astimezone(ZoneInfo(zb)).isoformat(timespec="seconds")
    if s_c.count(":") < 4:
        s_c += ":00"
    content.append(
        f"""
    tz_a = try Tz.fromTzdata("{za}", testing.allocator);
    tz_b = try Tz.fromTzdata("{zb}", testing.allocator);

    dt_a = try Datetime.fromUnix({ta}, Duration.Resolution.second, .{OPEN_BRACE}.tz=&tz_a{CLOSE_BRACE});
    dt_b = try Datetime.fromUnix({tb}, Duration.Resolution.second,  .{OPEN_BRACE}.tz=&tz_b{CLOSE_BRACE});
    dt_c = try dt_a.tzConvert(.{OPEN_BRACE}.tz=&tz_b{CLOSE_BRACE});
    dt_b = try dt_b.tzConvert(.{OPEN_BRACE}.tz=&tz_a{CLOSE_BRACE});

    try dt_b.toString("%Y-%m-%dT%H:%M:%S%::z", s_b.writer());
    try testing.expectEqualStrings("{s_b}", s_b.items);
    try dt_c.toString("%Y-%m-%dT%H:%M:%S%::z", s_c.writer());
    try testing.expectEqualStrings("{s_c}", s_c.items);

    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();\n"""
    )

content.append("}\n")

with open(dst, "w") as fobj:
    fobj.writelines(content)
