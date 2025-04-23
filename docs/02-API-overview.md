# API Overview

## Datetime

### _Input:_ Make a Datetime

#### Now

- [`zdt.Datetime.now`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.now) - with an optional time zone or UTC offset (see [`tz_options`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.tz_options)).
- [`zdt.Datetime.nowUTC`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.nowUTC) - a fail-safe shortcut to get UTC datetime.

#### From fields

- [`zdt.Datetime.fromFields`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.fromFields) - year, month, day etc.; see also [`zdt.Datetime.Fields`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.Fields) struct.

#### From a string

- [`zdt.Datetime.fromString`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.fromString) - see [parsing directives](https://github.com/FObersteiner/zdt/wiki/String-parsing-and-formatting-directives).
- [`zdt.Datetime.fromISO8601`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.fromISO8601) - shortcut to parse [ISO8601](https://en.wikipedia.org/wiki/ISO_8601)-compatible input formats.

#### From Unix time

- [`zdt.Datetime.fromUnix`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.fromUnix) - must specify a resolution (seconds, microseconds etc.) for the input quantity; see also [`zdt.Duration.Resolution`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.Resolution). Optional  time zone or UTC offset.

### _Output:_ Datetime to something else

#### To string

- [`zdt.Datetime.toString`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.toString) - see [formatting directives](https://github.com/FObersteiner/zdt/wiki/String-parsing-and-formatting-directives). Can either be called as a library function (`zdt.Datetime.toString`) or as a method of a datetime instance `dt`; `dt.toString`.

#### To Unix time

- [`zdt.Datetime.toUnix`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.toUnix) - a resolution must be specified, see `fromUnix`. Also to be called either as a library function or instance method.

#### To ISO calendar

- [`zdt.Datetime.toISOCalendar`](https://fobersteiner.github.io/zdt/#zdt.lib.Datetime.toISOCalendar)

## Duration

### _Input:_ Make a Duration

#### From an [ISO8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) string, absolute

- [`zdt.Duration.fromISO8601`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.fromISO8601) - note: since the Duration type represents an absolute difference in time, years and months are not allowed (see `RelativeDelta`).

#### From an ISO8601 duration string, relative timespan ("wall-time")

- [`zdt.Duration.RelativeDelta.fromISO8601`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.RelativeDelta.fromISO8601) - might include years and months.

#### From multiples of a timespan

- [`zdt.Duration.fromTimespanMultiple`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.fromTimespanMultiple)

### _Output:_ Duration to something else

#### To multiple of a timespan

- [`zdt.Duration.toTimespanMultiple`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.toTimespanMultiple)

#### Total seconds

- [`zdt.Duration.totalSeconds`](https://fobersteiner.github.io/zdt/#zdt.lib.Duration.totalSeconds)

## Timezone

#### From embedded tz database

- [`zdt.Timezone.fromTzdata`](https://fobersteiner.github.io/zdt/#zdt.lib.Timezone.fromTzdata)

#### From system tz database

- [`zdt.Timezone.fromSystemTzdata`](https://fobersteiner.github.io/zdt/#zdt.lib.Timezone.fromSystemTzdata). See also: `prefix_tzdb` option from build.zig - `Timezone.tzdb_prefix` can be used as db_path.
- [`zdt.Timezone.tzLocal`](https://fobersteiner.github.io/zdt/#zdt.lib.Timezone.tzLocal) - try to obtain the local time zone from the system.

#### From a POSIX TZ string

- [`zdt.Timezone.fromPosixTz`](https://fobersteiner.github.io/zdt/#zdt.lib.Timezone.fromPosixTz)
