from datetime import datetime, timezone
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
    var dt_b = datetime.Datetime{};"""
)

for _ in range(3):
    za, zb = random.sample(allzones, 2)
    ta, tb = random.sample(unixrange, 2)
    dta = datetime.fromtimestamp(ta, tz=ZoneInfo(za))
    dtb = datetime.fromtimestamp(tb, tz=ZoneInfo(zb))
    # print(za, zb)
    # print(ta, tb)
    # print(dta, dtb)
    # print(int((dtb - dta).total_seconds()), tb - ta)
    print(
        f"""
    tz_a = try tz.fromTzfile("{za}", std.testing.allocator);
    tz_b = try tz.fromTzfile("{zb}", std.testing.allocator);
    dt_a = try datetime.Datetime.fromUnix({ta}, Duration.Resolution.second, tz_a);
    dt_b = try datetime.Datetime.fromUnix({tb}, Duration.Resolution.second, tz_b);
    tz_a.deinit();
    tz_b.deinit();"""
    )


print("}")
