<!-- -*- coding: utf-8 -*- -->

# Miscellaneous and Advanced

## similar projects in Zig

- [zeit](https://github.com/rockorager/zeit), datetime and time zone library
- [datetime](https://github.com/clickingbuttons/datetime), generic Date, Time, and DateTime library, time zone handling not implemented
- [tempus](https://github.com/jnordwick/tempus), time library with focus on performance & low level stuff
- [zig-datetime](https://github.com/frmdstryr/zig-datetime), Python-arrow like semantics, time zones only represented by fixed offsets
- [zig-time](https://github.com/nektro/zig-time), date/time parsing/formatting, no time zone features
- [chrono-zig](https://codeberg.org/geemili/chrono-zig), a port of Rust's `chrono` crate
- Karl Seguin's [zig utility library](https://github.com/karlseguin/zul) also offers some date/time functionality (no time zone features)

Related:
- [zig-tzif](https://github.com/leroycep/zig-tzif), TZif and POSIX TZ string parsing library

## why does `Datetime.now(null)` give a UTC-like datetime ?

If you supply `null` (no time zone), the fields of the returned datetime will resemble UTC. This is a compromise. You can convert that to Unix time and it will be "correct". If the returned datetime would resemble your local time, the conversion to Unix time would not be possible without knowing the according offset from UTC. So the choice boils down to: you cannot convert naive datetime to Unix time _or_ naive datetime is _treated_ like it was UTC.

## Ambiguous and Non-Existent Datetime: folds and gaps

A datetime is ambiguous if it appears multiple times on a wall clock:

- DST transition fold: wall clock moved backwards when daylight saving time goes from active to inactive

A datetime is non-existent if it does not appear on a wall clock:

- DST transition gap: wall clock moved forwards when daylight saving time goes from inactive to active

The [DST tag wiki](https://stackoverflow.com/tags/dst/info) on StackOverflow has a nice illustration for this.

## IANA time zone identifiers vs. Windows time zone names

This library works with the IANA database exclusively. Therefore, a mapping is required if a Windows time zone should be acquired. For example, this is needed in `Timezone.tzLocal`. Since IANA db and Windows db do not strive to achieve an unambiguous mapping between the databases, this method is error-prone. `zdt` uses the mapping provided by the [Unicode CLDR Project](https://cldr.unicode.org/). The mapping is updated by `/util/gen_wintz_mapping.py`.

Some resources related to this:

- Jon Skeet [on StackOverflow](https://stackoverflow.com/a/71873868/10197418)
- [timezone tag wiki](https://stackoverflow.com/tags/timezone/info) on StackOverflow
