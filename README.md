# zdt

Exploring datetime with time zones in Zig.

## Demo

For example, build and run the [datetime example](https://codeberg.org/FObersteiner/zdt/src/branch/main/examples/ex_datetime.zig):

```zig
zig build examples && ./zig-out/bin/ex_datetime
```

## Status

### working

- basic parsing, from string to datetime and vice versa
- datetime to / from Unix time, datetime from fields (year, month, day, etc.)
  - everything including time zone handling, fixed offset and IANA-db TZif
- setting, changing and removing time zone information from datetime

### planned

- see also <https://codeberg.org/FObersteiner/zdt/issues>
- duration arithmetic
- calendric calculations, ISO calendar
- POSIX TZ support
- extended testing for time zone handling
- extended parsing / formatting

## Limitations

IANA-db time zone support currently only works on Linux (tested on debian)

## Credits

- influenced by: Python's datetime and zoneinfo modules, as well as datetime in the pandas package
- calendric calculations: Howard Hinnant's 'date' algorithms, <https://howardhinnant.github.io/date_algorithms.html>, as well as Cassio Neri's talk on "Euclidean affine functions", <https://github.com/cassioneri/eaf>, and Travis Staloch's translation to Zig, <https://github.com/travisstaloch/date-zig/>
- string input output: parser adapted from LeRoyce Pearson's chrono-zig, <https://codeberg.org/geemili/chrono-zig>
