from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo
import zoneinfo
import random

OPEN_BRACE = "{"
CLOSE_BRACE = "}"
N = 25

# zoneinfo needs to use tz path of the module
zoneinfo.reset_tzpath(
    to=((Path(__file__).parent / ".." / "lib" / "tzdata" / "zoneinfo").resolve(),)
)

dst = (Path(__file__).parent / ".." / "tests" / "test_timezone.zig").resolve()
search = "// the following test is auto-generated. do not edit this line and below.\n"

with open(dst, "r") as fobj:
    content = fobj.readlines()

idx = content.index(search)
assert idx > 0

content = content[: idx + 1]
content.append("\n")

random.seed(314)

allzones = tuple(zoneinfo.available_timezones())
unixrange = range(-2145920400, 2145913200)

content.append(
    """test "conversion between random time zones" {
    var tz_a = Tz{};
    var tz_b = Tz{};
    defer tz_a.deinit();
    defer tz_b.deinit();
    var dt_a = Datetime{};
    var dt_b = Datetime{};
    var dt_c = Datetime{};
    var s_b = std.ArrayList(u8).init(testing.allocator);
    var s_c = std.ArrayList(u8).init(testing.allocator);
    defer s_b.deinit();
    defer s_c.deinit();\n"""
)

for _ in range(N):
    za, zb = random.sample(allzones, 2)
    ta, tb = random.sample(unixrange, 2)
    dta = datetime.fromtimestamp(ta, tz=ZoneInfo(za))
    dtb = datetime.fromtimestamp(tb, tz=ZoneInfo(zb))
    s_b = dtb.astimezone(ZoneInfo(za)).isoformat(timespec="seconds")
    s_c = dta.astimezone(ZoneInfo(zb)).isoformat(timespec="seconds")
    content.append(
        f"""
    tz_a = try Tz.fromTzfile("{za}", std.testing.allocator);
    tz_b = try Tz.fromTzfile("{zb}", std.testing.allocator);
    dt_a = try Datetime.fromUnix({ta}, Duration.Resolution.second, tz_a);
    dt_b = try Datetime.fromUnix({tb}, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatDatetime(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("{s_b}", s_b.items);
    try str.formatDatetime(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("{s_c}", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();\n"""
    )

content.append("}\n")

with open(dst, "w") as fobj:
    fobj.writelines(content)
