# zdt

Exploring datetime with time zones in Zig.

```zig
  var tz_LA = try zdt.Timezone.fromTzfile("America/Los_Angeles", allocator);
  defer tz_LA.deinit();
  var tz_Paris = try zdt.Timezone.fromTzfile("Europe/Paris", allocator);
  defer tz_Paris.deinit();

  const a_datetime = try zdt.stringIO.parseISO8601("2022-03-07");
  const this_time_LA = try a_datetime.tzLocalize(tz_LA);
  const this_time_Paris = try this_time_LA.tzConvert(tz_Paris);

  std.debug.print(
      "Time, LA : {s}\n... that's {s} in Paris\n",
      .{ this_time_LA, this_time_Paris },
  );
  // Time, LA : 2022-03-07T00:00:00-08:00
  // ... that's 2022-03-07T09:00:00+01:00 in Paris

  const wall_diff = try this_time_Paris.diffWall(this_time_LA);
  const abs_diff = this_time_Paris.diff(this_time_LA);

  std.debug.print(
      "Wall clock time difference: {s}\nAbsolute time difference: {s}\n",
      .{ wall_diff, abs_diff },
  );
  // Wall clock time difference: PT09H00M00S
  // Absolute time difference: PT00H00M00S
```

You can find more examples in the `./examples` directory. There is a build-step to build them all; you can build and run them like

```zig
zig build examples && ./zig-out/bin/ex_datetime
```

## Zig version

This library is developed with Zig `0.12.0-dev`, mostly at the bleeding edge. Zig is evolving - the code likely won't compile with older versions.

## Time zone database

`zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt`. If you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`

## Development status

Ongoing. Recent changes: see [changelog](https://codeberg.org/FObersteiner/zdt/src/branch/main/doc/Change.log).

### Features

- datetime to / from Unix time, datetime from fields (year, month, day, etc.)
- time zone handling, fixed offset and IANA-db "tzfile" (TZif format)
- setting, changing and removing time zone information from datetime
- basic parsing, from string to datetime and vice versa
- ISO8601 parser
- duration arithmetic

### Planned

See [issues](https://codeberg.org/FObersteiner/zdt/issues).

## Limitations

- leap second support is limited to it being accepted as a datetime field (seconds = 60)
- non-ASCII characters (e.g. Unicode hyphen U+2010) aren't supported in datetime strings
- duration arithmetic does not support wall-time (addition, subtraction)

## Credits

- influenced (and motivated) by: Python's datetime and zoneinfo modules, datetime implementation in the pandas package
- calendric calculations: Howard Hinnant's 'date' algorithms, <https://howardhinnant.github.io/date_algorithms.html>, Cassio Neri's talk on "Euclidean affine functions", <https://github.com/cassioneri/eaf>, and Travis Staloch's translation to Zig, <https://github.com/travisstaloch/date-zig/>
- string input/output: parser adapted from LeRoyce Pearson's chrono-zig, <https://codeberg.org/geemili/chrono-zig>

---

The original repo is hosted [on Codeberg](https://codeberg.org/FObersteiner/zdt).
