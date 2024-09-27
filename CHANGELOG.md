# CHANGELOG

<https://keepachangelog.com/>

Types of changes

- 'Added' for new features.
- 'Changed' for changes in existing functionality.
- 'Deprecated' for soon-to-be removed features.
- 'Removed' for now removed features.
- 'Fixed' for any bug fixes.
- 'Security' in case of vulnerabilities.

## Unreleased

### Added

- datetime to string
  - formatting directive modifier ':', like Rust's chrono strftime has for '%z'
  - '%C' formatting directive to get 2-digit century

### Changed

- internal: re-write datetime string parser / formatter
- datetime string parsing/formatting: directive '%+' now parses/formats to ISO8601 (was: '%T')

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
