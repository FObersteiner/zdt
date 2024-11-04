# -*- coding: utf-8 -*-
from datetime import datetime, timedelta, timezone
from collections import namedtuple

# fmt: off

LeapSecond = namedtuple('LeapSecond', 'utc dTAI_UTC')

leaps = (
    LeapSecond(utc=datetime(1972, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 11)),
    LeapSecond(utc=datetime(1973, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 12)),
    LeapSecond(utc=datetime(1974, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 13)),
    LeapSecond(utc=datetime(1975, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 14)),
    LeapSecond(utc=datetime(1976, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 15)),
    LeapSecond(utc=datetime(1977, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 16)),
    LeapSecond(utc=datetime(1978, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 17)),
    LeapSecond(utc=datetime(1979, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 18)),
    LeapSecond(utc=datetime(1980, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 19)),
    LeapSecond(utc=datetime(1981, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 20)),
    LeapSecond(utc=datetime(1982, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 21)),
    LeapSecond(utc=datetime(1983, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 22)),
    LeapSecond(utc=datetime(1985, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 23)),
    LeapSecond(utc=datetime(1988, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 24)),
    LeapSecond(utc=datetime(1990, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 25)),
    LeapSecond(utc=datetime(1991, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 26)),
    LeapSecond(utc=datetime(1992, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 27)),
    LeapSecond(utc=datetime(1993, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 28)),
    LeapSecond(utc=datetime(1994, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 29)),
    LeapSecond(utc=datetime(1996, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 30)),
    LeapSecond(utc=datetime(1997, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 31)),
    LeapSecond(utc=datetime(1999, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 32)),
    LeapSecond(utc=datetime(2006, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 33)),
    LeapSecond(utc=datetime(2009, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 34)),
    LeapSecond(utc=datetime(2012, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 35)),
    LeapSecond(utc=datetime(2015, 7, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 36)),
    LeapSecond(utc=datetime(2017, 1, 1, 0, 0, tzinfo=timezone.utc), dTAI_UTC=timedelta(0, 37)),
)

print(
    """test "leap correction" {
    var corr: u8 = cal.leapCorrection(0);
    try testing.expectEqual(@as(u8, 10), corr);"""

)
for ls in leaps:
    print(
f"""    corr = cal.leapCorrection({int(ls.utc.timestamp()-1)});
    try testing.expectEqual(@as(u8, {int(ls.dTAI_UTC.total_seconds()-1)}), corr);
    corr = cal.leapCorrection({int(ls.utc.timestamp())});
    try testing.expectEqual(@as(u8, {int(ls.dTAI_UTC.total_seconds())}), corr);"""
    )


print("}")
