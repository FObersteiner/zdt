[![Zig](https://img.shields.io/badge/-Zig-F7A41D?style=flat&logo=zig&logoColor=white)](https://ziglang.org/) ⚡ [![tzdata](https://img.shields.io/badge/tzdata-2025b-blue)](https://www.iana.org/time-zones) [![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)

# zdt

## Please Note

**This repository is a mirror of [zdt on Codeberg](https://codeberg.org/FObersteiner/zdt).**

## Core Features

- **datetime** - including **duration** arithmetic
- **timezones** - IANA tzdb / TZif, POSIX, fixed offsets
- **parsers/formatters** - ISO8601 (datetime and durations), custom datetime parsing/formatting à la `strptime` / `strftime`

## Resources

- [API overview](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/02-API-overview.md)
- [Autodocs](https://fobersteiner.codeberg.page/#zdt)
- [Examples](https://codeberg.org/FObersteiner/zdt/src/branch/main/examples)
- [String parsing / formatting directives](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/03-String-parsing-and-formatting-directives.md)
- [Roadmap](https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/05-Roadmap.md)

### [Demo](https://github.com/FObersteiner/zdt/blob/master/examples/demo.zig)

```zig
// Can use an allocator for the time zones as the size of the rule-files varies.
var dba = std.heap.DebugAllocator(.{}){};
defer _ = dba.deinit();
const allocator = dba.allocator();

// zdt embeds the IANA tz database (about 700k of raw data).
// If you pass null instead of the allocator, a fixed-size structure will be used - faster, but more mem required.
var tz_LA = try zdt.Timezone.fromTzdata("America/Los_Angeles", allocator);
defer tz_LA.deinit();

// You can also use your system's tz data at runtime;
// this will very likely not work on Windows, so we use the embedded version here as well.
var tz_Paris = switch (builtin.os.tag) {
    .windows => try zdt.Timezone.fromTzdata("Europe/Paris", allocator),
    else => try zdt.Timezone.fromSystemTzdata("Europe/Paris", zdt.Timezone.tzdb_prefix, allocator),
};
defer tz_Paris.deinit();

// ISO8601 parser on-board, accepts wide variety of compatible formats
const a_datetime = try zdt.Datetime.fromISO8601("2022-03-07");
const this_time_LA = try a_datetime.tzLocalize(.{ .tz = &tz_LA });

// string output requires buffer memory...
var buf: [16]u8 = std.mem.zeroes([16]u8);
var w = std.Io.Writer.fixed(&buf);
try this_time_LA.toString("%I %p, %Z", &w);

const this_time_Paris = try this_time_LA.tzConvert(.{ .tz = &tz_Paris });

// '{f}' directive gives ISO8601 format by default;
std.debug.print(
    "Time, LA : {f} ({s})\n... that's {f} in Paris ({s})\n\n",
    .{ this_time_LA, buf, this_time_Paris, this_time_Paris.tzAbbreviation() },
);
// Time, LA : 2022-03-07T00:00:00-08:00 (12 am, PST)
// ... that's 2022-03-07T09:00:00+01:00 in Paris

const wall_diff = try this_time_Paris.diffWall(this_time_LA);
const abs_diff = this_time_Paris.diff(this_time_LA);

std.debug.print("Wall clock time difference: {f}\nAbsolute time difference: {f}\n\n", .{ wall_diff, abs_diff });
// Wall clock time difference: PT9H
// Absolute time difference: PT0S

// Easteregg:
std.debug.print(
    "Easter this year is on {f}\n",
    .{try zdt.Datetime.EasterDate(zdt.Datetime.nowUTC().year)},
);
// Easter this year is on 2025-04-20T00:00:00
```

## Credits

Special thanks to the creators of the following resources:

- inspiration for early version of string-to-datetime parser, and most of the POSIX TZ code: [leroycep/zig-tzif](https://github.com/leroycep/zig-tzif)
- date <--> days since Unix epoch conversion, algorithms: [cassioneri/eaf](https://github.com/cassioneri/eaf)
- general support from [ziggit.dev](https://ziggit.dev/)

## Development

See [changelog](https://codeberg.org/FObersteiner/zdt/src/branch/main/CHANGELOG.md)

- To update the time zone database and the version info, run the following build step: `zig build update-tzdb`. Some of the code generation is done with Python scripts, which require Python >= 3.9 but no third party packages, i.e. a system installation will do.

## Zig version requirements

- `v0.8.x`: Zig 0.15.1 (0.16-dev *may* work)
- `v0.7.x`: Zig 0.14 / 0.14.1
- `v0.6.x`: Zig 0.14 / 0.14.1
- `v0.5.x`: Zig 0.13 / 0.14
- `v0.4.x`: Zig 0.13

`zdt` is developed with Zig 'master' - this might sometimes introduce version incompatibilities. If you just want to use the library, use a tagged version that suites your Zig version.

## IANA timezone database version

- `v0.6.2+`: `2025b` (current)
- `v0.4.5+`: `2025a`
- `v0.2.2+`: `2024b`
- `<= v0.2.1`: `2024a`

## Dependencies

- No dependencies on other Zig libraries
- Time zone database: `zdt` comes with [eggert/tz](https://github.com/eggert/tz). The database is compiled and shipped with `zdt`.
- if you wish to use your own version of the [IANA time zone db](https://www.iana.org/time-zones), you can set a path to it using the `-Dprefix-tzdb="path/to/your/tzdb"` option. See also `zig build --help`.

## License

Unlicense (public domain). See the LICENSE file in the root directory of the repository.
