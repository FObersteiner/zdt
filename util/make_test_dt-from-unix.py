# -*- coding: utf-8 -*-
import random
from datetime import datetime, timezone

random.seed(0)

OPEN_BRACE = "{"
CLOSE_BRACE = "}"

# --- seconds, use full range ---

# UNIX_s_MIN = -62_135_596_800
# UNIX_s_MAX = 253_402_300_799
#
# print('test "unix seconds, fields" {')
# for s in random.sample(range(UNIX_s_MIN, UNIX_s_MAX + 1), 100):
#     dt = datetime.fromtimestamp(s, tz=timezone.utc)
#     print(
#         f"""  // {dt.isoformat()} :
#   dt_from_unix = try zdt.Datetime.from_unix({s}, zdt.Timeunit.second);
#   dt_from_fields = try zdt.Datetime.from_fields(.{OPEN_BRACE}.year={dt.year}, .month={dt.month}, .day={dt.day}, .hour={dt.hour}, .minute={dt.minute}, .second={dt.second}, .nanosecond=0{CLOSE_BRACE});
#   try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
# """
#     )
# print("}")

# --- nanoseconds, use narrow range to avoid floating point arithmetic errors ---

UNIX_us_MIN = -2208988800000000  # year 1900
UNIX_us_MAX = 4102444800000000  # year 2100

print('test "unix nanoseconds, fields" {')
for us in random.sample(range(UNIX_us_MIN, UNIX_us_MAX + 1), 100):
    dt = datetime.fromtimestamp(us / 1e6, tz=timezone.utc)
    print(
        f"""  // {dt.isoformat()} :
  dt_from_unix = try zdt.Datetime.from_unix({us*1000}, zdt.Timeunit.nanosecond);
  dt_from_fields = try zdt.Datetime.from_fields(.{OPEN_BRACE}.year={dt.year}, .month={dt.month}, .day={dt.day}, .hour={dt.hour}, .minute={dt.minute}, .second={dt.second}, .nanosecond={(us % 1_000_000) * 1000}{CLOSE_BRACE});
  try std.testing.expect(std.meta.eql(dt_from_unix, dt_from_fields));
"""
    )
    # print(dt, (us % 1_000_000) * 1000)
print("}")
