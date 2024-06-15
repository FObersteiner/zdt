<!-- -*- coding: utf-8 -*- -->

# zdt

**Datetime with Timezones in Zig.** Opinionated. For learning purposes.

The original repository is hosted [on Codeberg](https://codeberg.org/FObersteiner/zdt).

Demo:

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

This library is developed with Zig `0.14.0-dev`, might not compile with older versions. As of 2024-06-15, Zig-0.12 and Zig-0.13 (both stable) should work.

## Time zone database

`zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt` (as-is; not tar-balled or compressed). If you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`

For development, to update the time zone database and the version info, run the following build steps: `zig build tz-update-db && zig build tz-update-version`.

## License

MPL. See the LICENSE file in the root directory of the repository.
