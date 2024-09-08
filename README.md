<!-- -*- coding: utf-8 -*- -->
[![Zig](https://img.shields.io/badge/-Zig-F7A41D?style=flat&logo=zig&logoColor=white)](https://ziglang.org/) ⚡ [![tests](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml/badge.svg)](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml)  [![GitHub Release](https://img.shields.io/github/v/release/FObersteiner/zdt)](https://github.com/FObersteiner/zdt/releases)  [![tzdata](https://img.shields.io/badge/tzdata-2024b-blue)](https://www.iana.org/time-zones)  [![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://github.com/FObersteiner/zdt/blob/master/LICENSE)

# zdt

**Datetime with Timezones in Zig.** Opinionated, and mostly for learning purposes.

[Demo](https://github.com/FObersteiner/zdt/blob/master/examples/ex_demo.zig):

```zig
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  var tz_LA = try zdt.Timezone.fromTzfile("America/Los_Angeles", allocator);
  defer tz_LA.deinit();
  var tz_Paris = try zdt.Timezone.fromTzfile("Europe/Paris", allocator);
  defer tz_Paris.deinit();

  const a_datetime = try zdt.parseISO8601("2022-03-07");
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

More examples in the `./examples` directory. There's a build-step to build them all; EX:

```zig
zig build examples && ./zig-out/bin/ex_datetime
```

## Documentation

- [Introduction](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/01_intro.md)
- [Usage](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/02_usage.md)
- [Misc & Advanced](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/03_misc_advanced.md)

## Development

See [changelog](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/change.log).

## Zig version

This library is developed with Zig `0.14.0-dev`, might not compile with older versions. As of 2024-08-28, Zig-0.13 stable or higher should work.

## IANA timezone database version

- `zdt v0.2.2`: `2024b`
- `zdt v0.2.1` and older: `2024a`

## Dependencies, Development and Time zone database

`zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt` (as-is; not tar-balled or compressed). If you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`

For development, to update the time zone database and the version info, run the following build steps: `zig build update-tz-database && zig build update-tz-version`. Some of the code generation is done with Python scripts, which require Python >= 3.9 (no third party packages required).

## License

MPL. See the LICENSE file in the root directory of the repository.
