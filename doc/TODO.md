# general stuff

# examples

- examples could be normal executables instead of tests
- OK: datetime
- OK: duration
- OK: helpers

# utilities

- ISO calendar, ISO week number
- OK: month name, day name
- OK: nth weekday of the month
- OK: leap year, leap month
- OK: last_day_of_month
- OK: weekday
- OK: next_weekday
- OK: prev_weekday
- OK: day of year
- OK: week number

# Datetime struct

- from / to string (huge part !)
- OK: core functionality: days since Unix epoch from year-month-day
- OK: basic implementation
- OK: comparison
- OK: duration arithmetic
- OK: from / to Unix time => range checks
- OK: default string repr

# Duration struct

- from / to string
- add a 'repeat' function (or 'mul'?) to repeat a certain duration n times
- constants: microseconds, ..., seconds, ..., weeks ?
- OK: basic implementation
- OK: comparison
- OK: default string repr

# time zone support

- read & work with TZif files (use zig std.tz)
- localize (make aware, remove awareness)
- convert (aware + new tz = aware in new tz)

# tests

- never hurts to have a lot...

# benchmarks

- OK: zBench
  - zBench: make minimum duration etc. configurable parameters?
- comparison to other implementations
