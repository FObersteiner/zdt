# zdt

Exploring datetime with time zones in Zig.

Original repo hosted [on Codeberg](https://codeberg.org/FObersteiner/zdt).

## Demo

See `./examples`. You can run them like

```zig
zig build examples && ./zig-out/bin/ex_datetime
```

## Status

### working

- datetime to / from Unix time, datetime from fields (year, month, day, etc.)
- time zone handling, fixed offset and IANA-db "tzfile" (TZif format)
- setting, changing and removing time zone information from datetime
- basic parsing, from string to datetime and vice versa
- ISO8601 parser

### planned

- see also <https://codeberg.org/FObersteiner/zdt/issues>
- duration arithmetic
- calendric calculations, ISO calendar
- POSIX TZ support
- extended testing for time zone handling
- extended parsing / formatting (%Z directive, combi-directives for ISO date/time)

## Limitations

- IANA-db time zone support currently only works on Unix-like systems that have their `zoneinfo` database at `usr/share/zoneinfo`
- leap second support is limited to it being accepted as a datetime field (seconds = 60)
- non-ASCII characters (e.g. Unicode hyphen U+2010) aren't supported in datetime strings

## Credits

- influenced by: Python's datetime and zoneinfo modules, datetime implementation in the pandas package
- calendric calculations: Howard Hinnant's 'date' algorithms, <https://howardhinnant.github.io/date_algorithms.html>, Cassio Neri's talk on "Euclidean affine functions", <https://github.com/cassioneri/eaf>, and Travis Staloch's translation to Zig, <https://github.com/travisstaloch/date-zig/>
- string input/output: parser adapted from LeRoyce Pearson's chrono-zig, <https://codeberg.org/geemili/chrono-zig>
