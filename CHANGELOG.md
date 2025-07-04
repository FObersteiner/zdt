# CHANGELOG

<https://keepachangelog.com/>

Types of changes

- 'Added' for new features.
- 'Changed' for changes in existing functionality.
- 'Deprecated' for soon-to-be removed features.
- 'Removed' for now removed features.
- 'Fixed' for any bug fixes.
- 'Security' in case of vulnerabilities.

## [Unreleased]

## 2025-06-23, v0.6.10

### Added

- min and max values for Duration type (public constants); these ensure that the Duration.asNanoseconds() method won't fail due to integer over-/underflow
- Duration.addClip and Duration.subClip methods which won't return an error. If the result would be out-of-range, it will be clipped to the min/max value for the Duration type.

### Changed

- API: Duration.add and Duration.sub methods now return an error.SecondsOutOfRange if the resulting Duration would not satisfy the min/max value for the Duration type
- to ensure there is no over-/underflow of the Duration type, Datetime difference calculation methods use Duration.fromTimespanMultiple to generate the result

### Removed

- `build.zig.zon`: scripts from the `scripts/` directory. Those are only needed for development.

## 2025-06-18, v0.6.9

### Added

- Datetime formatter / printing: add option to print any number of digits (0-9) for the fractional seconds by using the `{s:.n}` notation, with `n` specifying the number of digits.
- `zdt-types` example, size of the timezone database

### Fixed

- links in API overview docs (<https://codeberg.org/FObersteiner/zdt/src/branch/main/docs/02-API-overview.md>)
- `zdt-types` example, size of `UTCOffset`

## 2025-06-10, v0.6.8

### Changed

- Re-enable all tests that were disabled in v0.6.7.

### Fixed

- Python not found error in gen_tzdb script.

### Removed

- Slices from zero-allocation timezone type. This is now exclusively handled by keeping indices around or using sentinals.
- Pointer to timetype in the normal timezone type that takes an allocator. This allows to use a common type for both zero-allocation timezone transitions and normal timezone transitions.

## 2025-06-10, v0.6.7

### Added

- support for postgres / pg.zig timestamp conversion to Datetime by @brainblasted on Codeberg

### Fixed

- pointer-to-temporary-memory bug in `getSurroundingTimetypes`; fixed-size tzif rule. Fixed by using the timetype from the array (`__data...`) instead of trying to access the slice.
- pointer-to-temporary-memory bug in `getSurroundingTimetypes`; POSIX TZ rule. Fixed by returning a concrete type (3-element array of Timetype) instead of a pointer type (3-element array of pointers to Timetype).

## 2025-05-06, v0.6.6

### Added

- `Datetime.isLeapYear` - returns if a datetime is in a leap year
- `Datetime.isLeapMonth` - returns if a datetime is in a February of a leap year
- more tests for the calendaric calculations
- string length check and maximum length for POSIX TZ strings

### Changed

- revised conversion functions between Gregorian date and days since the Unix epoch ('rata die')
  - greatly enhances the range of dates that can be represented
  - is now a rather straight-forward conversion of the C++ code from the [EAF paper](https://onlinelibrary.wiley.com/doi/full/10.1002/spe.3172)
- revised test location; internal tests are in respective zig files now

### Fixed

- extend name buffer for Timezone so that POSIX TZ strings are displayed correctly

## 2025-04-23, v0.6.5

### Added

- Duration type methods
  - `Duration.totalMinutes()`
  - `Duration.totalHours()`
  - `Duration.totalDays()`

### Changed

- moved to Codeberg
- revised docstrings
- moved github wiki content to `./docs`
- make locale-specific tests more robust by testing different masks when trying to obtain/set the locale
- more tests for Duration methods (total...())

## 2025-04-05, v0.6.4

### Changed

- revised error return values for all functions: specify returned error sets whenever possible (exceptions: `anyerror` if there is an `anytype` input parameter)

### Fixed

- `Datetime.fromString`: return an error if an empty string is passed for input or directive

## 2025-03-29, v0.6.3

### Added

- ability for `Datetime.format` to ingest formatting directives like `Datetime.toString` can use (see #54)
- fixed-size data structure for TZif timezone - loading 10x faster (no heap memory required)

### Fixed

- tests in tzif.zig; were testing std lib tzif reader, now test this implementation

## 2025-03-23, v0.6.2

### Changed

- bump tzdb to 2025b ([release notes](https://github.com/eggert/tz/blob/2025b/NEWS))

## 2025-03-20, v0.6.1

### Added

- development: use pre-commit

### Changed

- development: build step for running tests is now `zig build test`
- TZif reader:
  - skip reading leap seconds / corrections since those are the same for all time zones and provided elsewhere by zdt
  - tweak buffer sizes for reading textual data
  - use power-of-two size integers consistently (Unix time is provided as i64 by TZif files)
- benchmark dependencies: versions bumped

### Removed

- support for version 0 TZif files (legacy)

## 2025-03-08, v0.6.0

### Added

- POSIX TZ handling

### Changed

- fall back to using POSIX TZ rules if zoned datetimes lie beyond the defined transition range (tzif) in the future
- method UTCoffset.fromSecond now requires a parameter "is_dst" (boolean) to be specified.

## 2025-03-04, v0.5.0

### Changed

- zon file: Zig 0.14 features
- labeled switches used in parsers (also requires Zig 0.14)
- use specific function to parse exactly n digits if possible
- for better performance:
  - parser subroutines `parseDigits` and `parseExactNDigits` do not catch error from `std.fmt.parseInt`
  - parsing of UTC offset does not catch error from `std.math.powi`

### Added

- calculate the date of Easter, two methods, one for Gregorian and one for Julian calendar
- benchmarking module in ./benchmark/ directory - pretty crude right now, to be continued...

## 2025-01-16, v0.4.5

### Changed

- tzdb update to release 2025a

## 2025-01-05, v0.4.4

Upgrade release, so that zdt build.zig works with the latest 0.14-dev.

### Added

- some more tests for Duration formatter

### Changed

- build.zig: tzdb generator steps use  `b.graph.host` instead of `b.host` (zig 0.13 to 0.14 change)

## 2024-11-10, v0.4.3

### Added

- Datetime method 'addRelative' to add a RelativeDelta to a Datetime
- ISO duration parser 'W' directive / relative delta type can handle weeks
- Normalizer for the fields of a RelativeDelta (set fields to their "natural" modulo; e.g. hours = [0..23]).

### Changed

- ISO duration parser only accepts a minus prefix ('-') to indicate a negative duration. Individual quantities must not be signed.
- Conversion from RelativeDelta to Duration type now a method of RelativeDelta

### Fixed

- ISO duration format validation for incorrect order of quantities and position of 'T'

## 2024-11-04, v0.4.2

### Added

- ISO8601 duration parser

### Changed

- revised examples; type infos now in a separate file 'ex_zdt-types.zig'

### Fixed

- default formatter of the Duration type to 'ISO8601 duration'-like string, correct output
- datetime parsing / from fields: leap seconds are now validated, i.e. a random datetime cannot have seconds == 60 anymore

## 2024-10-28, v0.4.1

### Added

- test UTC Timezone can be deinitialized safely
- test UTC offset of a datetime stays untouched if its Timezone gets deinitialized

### Changed

- make Timezone.deinit take a pointer to a Timezone instead of a *const (Timezones must be declared as 'var') - by @Ratakor
- (breaking) renamed: 'Timezone.runtimeFromTzfile' to 'Timezone.fromSystemTzdata'

### Fixed

- Timezone.UTC can be deinitialized safely now (see Timezone.deinit change) - by @Ratakor

## 2024-10-27, v0.4.0

### Added

- datetime parser:
  - option to use a modifier in parsing directives
  - allow parsing of English month/day names, independent of the current locale
- leap seconds:
  - method 'validateLeap' to test whether a datetime with seconds == 60 actually is a leap second datetime
  - method 'diffLeap' to calculate difference in leap seconds between two datetimes
- offset / time zone handling:
  - new type / struct 'UTCoffset', which is used to specify a concrete offset from UTC for a zoned datetime
  - new helper union 'tz_options', to provide either a time zone or a UTC offset for functions that set or convert time zones of a datetime

### Changed

- (internal) improve Timezone.format method, remove usage of `@constCast` and reduce usage of `.?` on optionals - by @Ratakor
- (internal) Timezone handling as a tagged union for different sources of rules (IANA db TZif or POSIX; POSIX only prepared, not implemented yet)
- API changes (breaking):
  - time zones are generally passed as a pointer to a const
  - datetime creation: methods 'fromFields' and 'fromUnix' now take an optional 'tz_options', which is a tagged union that either can be a UTC offset or a Timezone
  - time zone set / change: methods 'tzLocalize' and 'tzConvert' also now take 'tz_options'
  - 'Datetime.now': also takes 'tz_options' now instead of a Timezone

### Removed

- method 'fromTzfile' (Timezone creation). A Timezone should either be created from the embedded tzdata (method 'fromTzdata', comptime or runtime) or at runtime from the system's tzdata (method 'runtimeFromTzfile')

## 2024-10-12, v0.3.5

### Added

- parser for locale-specific day and month names (Unix)
  - note: setting the locale on Windows has proven difficult - requires more work
- (internal) handle parser flags as an enum

### Changed

- (internal) clean-up of month/day name functions

## 2024-10-08, v0.3.4

### Added

- leap second difference between two datetimes: method 'diffLeap', returns Duration type
- 'replace' method to safely change fields of a datetime
- 'toFields' method for datetime

### Changed

- tzdb version info now part of tzdata.zig, since this is specific to the embedded version
- update info on how to update tzdata for development
- isocalendar: 'year' field is now called 'isoyear'

### Removed

- gen_tzdb_version script; this is now part of the tzdb_update script

## 2024-10-04, v0.3.3

### Added

- ISO-calendar: 'toDatetime' method
- Datetime to string / Formatter:
  - 't' directive to get ISO-calendar ("yyyy-Www-d")
  - 'Z' directive now has a modifier, which causes UTC to be displayed as 'UTC', not 'Z'
- Datetime from string / Parser:
  - 't' directive to get datetime from ISO-calendar
- Formats:
  - common formats, see <https://pkg.go.dev/time#pkg-constants>
- some doc comments regarding 'privacy' of Datetime attributes

### Fixed

- ISO Calendar: adjust year from Gregorian to ISO if necessary
- Datetime to string / Formatter:
  - 'G' directive / ISO-year

## 2024-10-03, v0.3.2

### Added

- ISO8601 parser:
  - '-' as a year-month or month-day separator now optional
  - ':' as a hour-minute or minute-second separator now optional
  - capability to parse day-of-year (ordinal; 'yyyy-ooo' format)
- Datetime from string / Parser:
  - 'j' directive to parse day-of-year
- Datetime to string / Formatter:
  - 's' directive to get Unix time in seconds
  - ':a', ':A', ':b', ':B' (modifier option) to get English day / month names, independent of locale

### Changed

- internal: ISO8601 parser revised

## 2024-09-30, v0.3.1

### Added

- datetime to string
  - formatting directive modifier ':', like Rust's chrono strftime has for '%z'
  - '%C' formatting directive to get 2-digit century

### Changed

- internal: re-write datetime string parser / formatter
- parsing/formatting directives:
  - formatting, 'z' gives offset without colon between hour and minute, ':z' gives the usual "+00:00"
  - formatting, 'p' gives "am" or "pm", 'P' gives "AM" or "PM"; parser ignores case
  - formatting, 'e' and 'k': space-padded day and hour

## 2024-09-20, v0.3.0

### Added

- method `nowUTC` to Datetime that returns UTC (aware datetime) without needing a timezone argument and returns no error

### Changed

- major API revision, mainly string input/output
  - Datetime now has `toString` and `fromString`, as well as `fromISO8601` as a shortcut for ISO8601-compatible input
  - string.zig and calendar.zig aren't exported anymore (stringIO.zig is now string.zig), to keep the API concise
- `now` returns an error union, in case loading the timezone causes an error

### Fixed

- `toString`: correctly handle naive datetime with 'i', 'z' and 'Z' directives

### Removed

- POSIX TZ provisions since this is currently not planned
- method `nowLocal` from Datetime; this can be achieved with `now` plus `Timezone.tzLocal`

## 2024-09-15, v0.2.3

- datetime to string: %I directive, by @sethvincent
- datetime to string, string to datetime: 'am' and 'pm' added, to complement %I
- formatting directives (dt-->str) mostly completed, missing: locale-specific `%c`, `%x` and `%X` (addresses part of issue #5)
- generator script, tz database: checkout specific tag before building the database (addresses part of issue #4)

## 2024-09-08, v0.2.2

- update IANA tzdata to 2024b

## 2024-08-28, v0.2.1

- change of ergonomics: `formatToString`, `parseToDatetime` and `parseISO8601` functions are now methods of the `zdt` struct (formerly `stringIO.[...]`). After importing zdt, they can be called like `zdt.formatToString` etc.
- this is the first version that will be on github only. Having the same repository at both Codeberg and github is just too cumbersome.

## 2024-08-07, v0.2.0

- add a complete embedding of the IANA tzdb that allows cross-compilation
  - since StaticStringMap is not available with Zig 0.12, Zig 0.13+ is required
- fix code generator steps in build.zig to only run on the host as target

## 2024-08-06, v0.1.6

- renamings; replace 'self' with more meaningful designation
- remove 'clean' step from build.zig
- last version that supports both Zig 0.12 and 0.13

## 2024-07-07, v0.1.5

- add option to truncate fractional second via 's.:[precision]' formatting directive
- limit what is exposed from ./util via the zon file
- satisfy zig-0.14 deprecations

## 2024-06-18, v0.1.4

- adjust to std lib updates (std.mem.split, std.fs.max_path_bytes)
- clean-up unused code in stringIO
- add %j directive, implement datetime --> string
- add %T directive, implement datetime <--> string

## 2024-06-15, v0.1.3

- introduce helper functions isAware and isNaive for Datetime struct
- make tz name validator public (Timezone.identifierValid)

## 2024-06-09

- cleaun-up calendar.zig

## 2024-05-30

- add autodoc workflow, gh pages

## 2024-05-28, v0.1.2

- re-instate autodocs feature
- some windows-tzdb generator tweaks
- tzdb update

## 2024-05-19, v0.1.1

- use base2 sized integers for better performance
- TZ format: use 'c'-directive to signal that those are ASCII-encoded strings

## 2024-05-04, v0.1.0

- cleanup

## 2024-04-04

- runtime loading of tzfile: accept period as part of identifier (path)

## 2024-03-16

- add 'dst_fold' datetime field to specify on which side of a DST 'fold' a datetime should fall
- add explicit check and error for (in)valid time zone identifier
- obtain tzdb version from tzdata.tz instead of git tag (no data - no version)
- revise build steps to handle tzdata update and tzdb_version.zig update
- remove `utcnow` method, can be done with `now(Timzone.UTC)`
- add 'clean' step to build.zig, to remove ./zig-out and ./zig-cache
- more stuff added to docs

## 2024-03-09

- add string input/output example
- revise string IO methods
- build.zig.zon: explicitly specify included files and directories
- windows-tz: read Windows tz name from registry instead of using `tzutil`

## 2024-02-28

- documentation updates
- add locale specific formatting directives %a, %A, %b and %B (datetime to string)
- tzLocalize: accept aware datetime (creates new datetime with same fields but different time zone)

## 2024-02-23

- mirror of the repo on codeberg.org is public on github.com
- add documentation (most of it still in preparation), update doc-comments
- refine duration methods, 'fromTimespanMultiple' and 'toTimespanMultiple'
- add duration example

## 2024-02-16

- bugfix `epoch` constant
- `UTC` tz struct re-implemented as a constant (was: function)
- remove `naiveFromList` method - datetime instance should be created via `fromFields`
- update readme, add demo (example)

## 2024-02-13

- revise name and abbreviation of time zones
- update tzdb version to 2024a

## 2024-02-09

- simplify API for timezone generation
- internal revision which methods should operate on pointers and which on values
- tz abbreviation awailable via formatDatetime method (stringIO module)

## 2024-01-31

- automatically set time zone database prefix when the library is used by another package
- tz db prefix can also set to a user-specified path via build options
- add local tz method (implemented for linux, windows)

## 2024-01-24

- add Paul Eggert's tz database as a submodule; TZif files are compiled into ./lib/tzdata/zoneinfo
- tzdata version stored in Timezone.tzdata_version; the constant is updated via the build-script
- tzfiles from the database that is shipped with zdt (eggert/tz) are comptime-loaded by default
- runtime-loading of TZif files now has to be done via a separate function

## 2024-01-19

- some restructuring where stuff is located in the module's directory, no effect on code itself
- prepare embedding zoneinfo data; latest version is obtained by Python script

## 2024-01-10

- add iso-calendar method for Datetime (generates ISOCalendar struct instance)
- add week of year method (non-iso)
- add nth weekday method (generate nth weekday of month)
- add next/previous weekday method (generates Datetime)
- add Month, Weekday and ISOCalendar types
- add docs generate step to build script
- add semantic version to build script

## 2024-01-07

- restructured datetime and timezone, both files now offer the type (struct) directly
- add tzif parser from the standard lib as a source file
- add epoch constant
- zig_0.12-dev branch: runs with latest dev version - fixes tz abbreviation bug, but excludes zBench since this requires 0.11.0

## 2024-01-03

- add timezone tests
- use a main-fn in benchmarks and examples
- use Neri-Schneider algorithms for date <--> Unix time
- add method to determine leap seconds offset for given Unix time

## 2024-01-02

- add day-of-year method
- add day-of-week and iso-day-of-week methods
- tzfile bugfix: correct offset determination for zones that only have one timetype

## 2024-01-02

- add basic duration arithmetic with datetime
- revise parser and ISO8601 parser
- parse 'Z' to a named offset, UTC
- add parser benchmark

## 2023-12-30

- parser / DatetimeFields: accept leap second input
- parser: fix bug with incomplete fractional input (< 9 digits)
- add ISO8601 parser

## 2023-12-27

- add examples (offset time zone, time zone)
- adhere to ziglang naming convention
- revise TZ deinit method, make sure to free tzfile memory

## 2023-12-22

- revise TZ struct and attachment logic of datetime-->timezone
- add comparison methods for UT and wall time
- add datetime demo

## 2023-12-21

- add 'now' method
- allow seconds in UTC offset

## 2023-12-21

- add datetime localization method
- add time zone conversion method
- offset tz: check range

## 2023-12-20

- datetime from fields with time zone handles ambiguous and non-existent datetime

## 2023-12-18

- add benchmark for calendric functions (r.d. <--> date)

## 2023-12-16

- some basic time zone calculations working

## 2023-12-10

- set 0.1.0 tag

## 2023-12-06

- prepare for restart

## 2023-11-26

- structural changes, where to put tests etc.
- include zBench via build.zig.zon

## 2023-11-23

- benchmarks as binary; install-artifact, not test in build script

## 2023-11-02

- integrate zBench from fork

## 2023-10-23

- created
