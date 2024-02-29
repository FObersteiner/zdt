<!-- -*- coding: utf-8 -*- -->

# Intro

`zdt` allows you to handle date & time with time zones in Zig. It supports the [Proleptic Gregorian calendar](https://en.wikipedia.org/wiki/Gregorian_calendar) in a range of years [1, 9999] AD.

## Types and Terms

`zdt` comes with 3 basic types:

- `Datetime`: an instant in time
- `Timezone`: a set of rules to describe local time somewhere on earth
- `Duration`: a difference in time

### Naive vs. Aware Datetime

A datetime without time zone rules is **_naive_**. It has no concept of locality. Once you attach a time zone to it, it becomes **_aware_** - it knows where it belongs. This has implications on comparability and duration arithmetic:

- you can only compare naive with naive, and aware with aware
- you can only calculate the duration between two datetime instances if they are comparable
- if both instances are aware, you have to further distinguish between
  - absolute time difference, i.e. the time period in a physical sense and
  - wall time difference, i.e. what you would observe on a wall clock[^1] that gets adjusted to daylight saving time (DST) etc.

## Limitations

- leap second support is limited to it being accepted as a datetime field (seconds = 60)
- non-ASCII characters (e.g. Unicode hyphen U+2010) aren't supported in datetime strings
- duration arithmetic does not support wall-time (addition, subtraction)

---

**_Footnotes_**

[^1]: Note that wall clocks can be difficult. Normally, you don't associate them with a time zone. However, a wall clock has to be at some geographical location, thus it has to follow the rules of some time zone. For example, I live in time zone "Europe/Berlin", so for example on 2022-03-27, it moved from 01:59:59 to 03:00:00. The actual time passed from 2 am and 3 am is zero. In contrast, a naive clock would move forward monotonically, no jumps forwards or backwards.
