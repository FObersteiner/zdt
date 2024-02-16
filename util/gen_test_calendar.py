# -*- coding: utf-8 -*-
import random
from datetime import datetime

random.seed(42)

OPEN_BRACE = "{"
CLOSE_BRACE = "}"
UNIX_ORDINAL = 719163
MAX_ORDINAL = 3652058

print('test "against Pyhton ordinal" {')
for d in random.sample(range(-UNIX_ORDINAL + 1, MAX_ORDINAL - UNIX_ORDINAL + 1), 50):
    dt = datetime.fromordinal(d + UNIX_ORDINAL)
    print(
        f"""    days_want = {d};
    days_hin = cal.unixdaysFromDate([_]u16{OPEN_BRACE} {dt.year}, {dt.month}, {dt.day} {CLOSE_BRACE});
    days_neri = cal.dateToRD([_]u16{OPEN_BRACE} {dt.year}, {dt.month}, {dt.day} {CLOSE_BRACE});
    try testing.expectEqual(days_want, days_hin);
    try testing.expectEqual(days_want, days_neri);

    date_want = [_]u16{OPEN_BRACE} {dt.year}, {dt.month}, {dt.day} {CLOSE_BRACE};
    date_hin = cal.dateFromUnixdays({d});
    date_neri = cal.rdToDate({d});
    try std.testing.expectEqual(date_want, date_hin);
    try std.testing.expectEqual(date_want, date_neri);
"""
    )

print(CLOSE_BRACE)
