<!-- -*- coding: utf-8 -*- -->

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](https://codeberg.org/FObersteiner/zdt/src/branch/main/LICENSE)
[![Build Status](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml/badge.svg)](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml)

# zdt

**Exploring datetime with time zones in Zig.** I created this project to have fun with Zig, learn a new language, and tackle the "do not roll your own datetime"-challenge. Use the outcome however you like - here's an example of something you can do with `zdt`:

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

## Documentation

- [Introduction](https://codeberg.org/FObersteiner/zdt/src/branch/main/doc/01_intro.md)
- [Usage](https://codeberg.org/FObersteiner/zdt/src/branch/main/doc/02_usage.md)
- [Misc & Advanced](https://codeberg.org/FObersteiner/zdt/src/branch/main/doc/03_misc_advanced.md)
- [TODO : API documentation (autodoc - experimental!)](TODO : add link)

## Development

Ongoing. Expect breaking changes. Recent changes: see the [changelog](https://codeberg.org/FObersteiner/zdt/src/branch/main/doc/change.log).

## Zig version

This library is developed with Zig `0.12.0-dev`, mostly at the bleeding edge. Zig is evolving - the code likely won't compile with older versions.

## Time zone database

`zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt`. If you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`

## Credits

- influenced and motivated by: Python's datetime and zoneinfo modules as well as the datetime implementation in the pandas and polars packages
- calendric calculations: Howard Hinnant's ['date' algorithms](https://howardhinnant.github.io/date_algorithms.html), [Cassio Neri's talk](https://github.com/cassioneri/eaf) on "Euclidean affine functions", and Travis Staloch's translation to Zig, [date-zig](https://github.com/travisstaloch/date-zig/)
- string input/output: parser heavily inspired by LeRoyce Pearson's [chrono-zig](https://codeberg.org/geemili/chrono-zig)
- the folks over at [ziggit.dev](https://ziggit.dev/), helping me with my technical struggles ;-)

---

The original repo is hosted [on Codeberg](https://codeberg.org/FObersteiner/zdt).
