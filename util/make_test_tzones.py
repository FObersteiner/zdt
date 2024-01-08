from datetime import datetime
from zoneinfo import ZoneInfo
import zoneinfo
import random

random.seed(314)

allzones = tuple(zoneinfo.available_timezones())
unixrange = range(-2145920400, 2145913200)

OPEN_BRACE = "{"
CLOSE_BRACE = "}"

print(
    """test "conversion between random time zones" {
    var tz_a = tz.TZ{};
    var tz_b = tz.TZ{};
    defer tz_a.deinit();
    defer tz_b.deinit();
    var dt_a = datetime.Datetime{};
    var dt_b = datetime.Datetime{};
    var dt_c = datetime.Datetime{};
    var s_b = std.ArrayList(u8).init(testing.allocator);
    var s_c = std.ArrayList(u8).init(testing.allocator);
    defer s_b.deinit();
    defer s_c.deinit();"""
)

for _ in range(15):
    za, zb = random.sample(allzones, 2)
    ta, tb = random.sample(unixrange, 2)
    dta = datetime.fromtimestamp(ta, tz=ZoneInfo(za))
    dtb = datetime.fromtimestamp(tb, tz=ZoneInfo(zb))
    s_b = dtb.astimezone(ZoneInfo(za)).isoformat(timespec="seconds")
    s_c = dta.astimezone(ZoneInfo(zb)).isoformat(timespec="seconds")
    print(
        f"""
    tz_a = try tz.fromTzfile("{za}", std.testing.allocator);
    tz_b = try tz.fromTzfile("{zb}", std.testing.allocator);
    dt_a = try datetime.Datetime.fromUnix({ta}, Duration.Resolution.second, tz_a);
    dt_b = try datetime.Datetime.fromUnix({tb}, Duration.Resolution.second, tz_b);
    dt_c = try dt_a.tzConvert(tz_b);
    dt_b = try dt_b.tzConvert(tz_a);
    try str.formatDatetime(s_b.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
    try testing.expectEqualStrings("{s_b}", s_b.items);
    try str.formatDatetime(s_c.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_c);
    try testing.expectEqualStrings("{s_c}", s_c.items);
    tz_a.deinit();
    tz_b.deinit();
    s_b.clearAndFree();
    s_c.clearAndFree();"""
    )


print("}")
