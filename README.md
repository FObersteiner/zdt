<!-- -*- coding: utf-8 -*- -->

[![Zig](https://img.shields.io/badge/-Zig-F7A41D?style=flat&logo=zig&logoColor=white)](https://ziglang.org/) ⚡ [![tests](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml/badge.svg)](https://github.com/FObersteiner/zdt/actions/workflows/zdt-tests.yml)  [![GitHub Release](https://img.shields.io/github/v/release/FObersteiner/zdt)](https://github.com/FObersteiner/zdt/releases)  [![tzdata](https://img.shields.io/badge/tzdata-2025a-blue)](https://www.iana.org/time-zones)  [![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://github.com/FObersteiner/zdt/blob/master/LICENSE)

# zdt

**Time<ins>z</ins>oned <ins>D</ins>ate<ins>t</ins>ime in Zig.** Opinionated, and mostly for learning purposes.

- [API overview](https://github.com/FObersteiner/zdt/wiki/API-overview)
- [Examples](https://github.com/FObersteiner/zdt/tree/master/examples)
- [Roadmap](https://github.com/FObersteiner/zdt/wiki/Roadmap)

### [Demo](https://github.com/FObersteiner/zdt/blob/master/examples/demo.zig)

```zig
// need an allocator for the time zones since the size of the rule-files varies.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

// zdt embeds the IANA tz database:
var tz_LA = try zdt.Timezone.fromTzdata("America/Los_Angeles", allocator);
defer tz_LA.deinit();

// you can also use your system's tz data at runtime;
// this will very likely not work on Windows, so we use the embedded version here as well.
var tz_Paris = switch (builtin.os.tag) {
    .windows => try zdt.Timezone.fromTzdata("Europe/Paris", allocator),
    else => try zdt.Timezone.fromSystemTzdata("Europe/Paris", zdt.Timezone.tzdb_prefix, allocator),
};
defer tz_Paris.deinit();

// ISO8601 parser on-board, accepts wide variety of compatible formats
const a_datetime = try zdt.Datetime.fromISO8601("2022-03-07");
const this_time_LA = try a_datetime.tzLocalize(.{ .tz = &tz_LA });

// string output also requires allocation...
var buf = std.ArrayList(u8).init(allocator);
defer buf.deinit();
try this_time_LA.toString("%I %p, %Z", buf.writer());

const this_time_Paris = try this_time_LA.tzConvert(.{ .tz = &tz_Paris });

// '{s}' directive gives ISO8601 format by default;
std.debug.print(
    "Time, LA : {s} ({s})\n... that's {s} in Paris ({s})\n\n",
    .{ this_time_LA, buf.items, this_time_Paris, this_time_Paris.tzAbbreviation() },
);
// Time, LA : 2022-03-07T00:00:00-08:00 (12 am, PST)
// ... that's 2022-03-07T09:00:00+01:00 in Paris

const wall_diff = try this_time_Paris.diffWall(this_time_LA);
const abs_diff = this_time_Paris.diff(this_time_LA);

std.debug.print("Wall clock time difference: {s}\nAbsolute time difference: {s}\n\n", .{ wall_diff, abs_diff });
// Wall clock time difference: PT9H
// Absolute time difference: PT0S

// Easteregg:
const now = zdt.Datetime.nowUTC();
const easter_date = try zdt.Datetime.EasterDate(now.year);
buf.clearAndFree();
try easter_date.toString("%B %d, %Y", buf.writer());
std.debug.print("Easter this year is on {s}\n", .{buf.items});
// Easter this year is on April 20, 2025
```

## Documentation

See [Wiki](https://github.com/FObersteiner/zdt/wiki)

## Credits

- inspiration for early version of string-to-datetime parser, and most of the POSIX TZ code: [leroycep/zig-tzif](https://github.com/leroycep/zig-tzif)
- date <--> days since Unix epoch conversion, algorithm: [cassioneri/eaf](https://github.com/cassioneri/eaf) ; Zig implementation: [travisstaloch/date-zig](https://github.com/travisstaloch/date-zig)
- general support from [ziggit.dev](https://ziggit.dev/)

## Development

See [changelog](https://github.com/FObersteiner/zdt/blob/master/CHANGELOG.md)

- For development: to update the time zone database and the version info, run the following build steps: `zig build update-tzdb`. Some of the code generation is done with Python scripts, which require Python >= 3.9 but no third party packages, i.e. a system installation will do.

## Zig version

- `v0.6.x`: Zig 0.14
- `v0.5.x`: Zig 0.13 / 0.14
- `v0.4.x`: Zig 0.13

This library is developed with Zig 'master' - this might sometimes introduce version incompatibilities. If you just want to use the library, use a tagged version that suites your Zig version.

## IANA timezone database version

- `v0.4.5+`: `2025a` (current)
- `v0.2.2+`: `2024b`
- `<= v0.2.1`: `2024a`

## Dependencies and time zone database

- No dependencies on other libraries
- Time zone database: `zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt`.
- if you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`.

## License

MPL. See the LICENSE file in the root directory of the repository.
