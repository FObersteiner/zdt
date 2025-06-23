# API Overview

## Datetime

### _Input:_ Make a Datetime

#### Now

- [`zdt.Datetime.now`](https://fobersteiner.codeberg.page/#zdt.Datetime.now) - with an optional time zone or UTC offset (see [`tz_options`](https://fobersteiner.codeberg.page/#zdt.Datetime.tz_options)).
- [`zdt.Datetime.nowUTC`](https://fobersteiner.codeberg.page/#zdt.Datetime.nowUTC) - a fail-safe shortcut to get UTC datetime.

#### From fields

- [`zdt.Datetime.fromFields`](https://fobersteiner.codeberg.page/#zdt.Datetime.fromFields) - year, month, day etc.; see also [`zdt.Datetime.Fields`](https://fobersteiner.codeberg.page/#zdt.Datetime.Fields) struct.

#### From a string

- [`zdt.Datetime.fromString`](https://fobersteiner.codeberg.page/#zdt.Datetime.fromString) - see [parsing directives](https://github.com/FObersteiner/zdt/wiki/String-parsing-and-formatting-directives).
- [`zdt.Datetime.fromISO8601`](https://fobersteiner.codeberg.page/#zdt.Datetime.fromISO8601) - shortcut to parse [ISO8601](https://en.wikipedia.org/wiki/ISO_8601)-compatible input formats.

#### From Unix time

- [`zdt.Datetime.fromUnix`](https://fobersteiner.codeberg.page/#zdt.Datetime.fromUnix) - must specify a resolution (seconds, microseconds etc.) for the input quantity; see also [`zdt.Duration.Resolution`](https://fobersteiner.codeberg.page/#zdt.Duration.Resolution). Optional  time zone or UTC offset.

### _Output:_ Datetime to something else

#### To string

- [`zdt.Datetime.toString`](https://fobersteiner.codeberg.page/#zdt.Datetime.toString) - see [formatting directives](https://github.com/FObersteiner/zdt/wiki/String-parsing-and-formatting-directives). Can either be called as a library function (`zdt.Datetime.toString`) or as a method of a datetime instance `dt`; `dt.toString`.

#### To Unix time

- [`zdt.Datetime.toUnix`](https://fobersteiner.codeberg.page/#zdt.Datetime.toUnix) - a resolution must be specified, see `fromUnix`. Also to be called either as a library function or instance method.

#### To ISO calendar

- [`zdt.Datetime.toISOCalendar`](https://fobersteiner.codeberg.page/#zdt.Datetime.toISOCalendar)

## Duration

### _Input:_ Make a Duration

#### From an [ISO8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) string, absolute

- [`zdt.Duration.fromISO8601`](https://fobersteiner.codeberg.page/#zdt.Duration.fromISO8601) - note: since the Duration type represents an absolute difference in time, years and months are not allowed (see `RelativeDelta`).

#### From an ISO8601 duration string, relative timespan ("wall-time")

- [`zdt.Duration.RelativeDelta.fromISO8601`](https://fobersteiner.codeberg.page/#zdt.Duration.RelativeDelta.fromISO8601) - the RelativeDelta sub-type might include the ambiguous quantities years and months.

#### From multiples of a timespan

- [`zdt.Duration.fromTimespanMultiple`](https://fobersteiner.codeberg.page/#zdt.Duration.fromTimespanMultiple)

### _Output:_ Duration to something else

#### To multiple of a timespan

- [`zdt.Duration.toTimespanMultiple`](https://fobersteiner.codeberg.page/#zdt.Duration.toTimespanMultiple)

#### Total seconds

- [`zdt.Duration.totalSeconds`](https://fobersteiner.codeberg.page/#zdt.Duration.totalSeconds) - there are equivalent methods for total minutes, hours etc.

## Timezone

#### From embedded tz database

- [`zdt.Timezone.fromTzdata`](https://fobersteiner.codeberg.page/#zdt.Timezone.fromTzdata)

#### From system tz database

- [`zdt.Timezone.fromSystemTzdata`](https://fobersteiner.codeberg.page/#zdt.Timezone.fromSystemTzdata). See also: `prefix_tzdb` option from build.zig - `Timezone.tzdb_prefix` can be used as db_path.
- [`zdt.Timezone.tzLocal`](https://fobersteiner.codeberg.page/#zdt.Timezone.tzLocal) - try to obtain the local time zone from the system.

#### From a POSIX TZ string

- [`zdt.Timezone.fromPosixTz`](https://fobersteiner.codeberg.page/#zdt.Timezone.fromPosixTz)
