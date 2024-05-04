<!-- -*- coding: utf-8 -*- -->

# Usage

We like to make things, so let's...

## Make a Datetime

From fields 'year', 'month', etc.:

```zig
const dt = try zdt.Datetime.fromFields(.{ .year = 2021, .month=12, .day=24 });
// 2024-12-24T00:00:00
```

- this might return an error if one of the field values is out of range - like a month greater 12 or a day=30 with month=2 combination
- anything you don't specify will get the default (minimum) value

You can also use Unix time in a resolution of your choice (seconds, milliseconds, etc.):

```zig
const dt = try zdt.Datetime.fromUnix(0, Duration.Resolution.second, null);
// 1970-01-01T00:00:00
```

- again, this can fail if the provided Unix time is out of range
- the third parameter has to be 'null' if no Timezone should be set - the resulting datetime will resemble UTC if no Timezone is set (e.g. Unix time 0 will give 1970-01-01 00:00:00)

## Make a Timezone

A Timezone can be loaded from the IANA database that comes with `zdt`. Since this requires memory allocation, the Timezone has to be a `var` and needs de-initialization after use.

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

var tz_berlin = try zdt.Timezone.fromTzfile("Europe/Berlin", allocator);
defer _ = tz.deinit();
```

- the creation can fail if the specified identifier does not exist in the database or something goes wrong when the database content is loaded into memory

A handy constant is `UTC`:

```zig
const utc_tz  = zdt.Timezone.UTC;
```

- since this is a fixed time zone, it does not to be loaded from the database and needs no additional memory allocation

## Make a Datetime with a Timezone

Now we can combine the two. Either set the Timezone as a field:

```zig
const dt = try zdt.Datetime.fromFields(.{ .year = 2021, .month=12, .day=24, .tzinfo=tz_berlin });
// 2024-12-24T00:00:00+01:00
```

Or as the third parameter to `fromUnix`:

```zig
const epoch = try zdt.Datetime.fromUnix(0, Duration.Resolution.second, zdt.Timezone.UTC);
// 1970-01-01T00:00:00+00:00
```

OK, we could have gotten the Unix epoch more easily by calling `zdt.Datetime.epoch`...

## Manipulate the Timezone

We can also set the time zone if it hasn't been set before

```zig
var dt = try zdt.Datetime.fromFields(.{ .year = 2021, .month=12, .day=24 });
// 2024-12-24T00:00:00
dt = try dt.tzLocalize(tz_berlin);
// 2024-12-24T00:00:00+01:00
```

Or convert the datetime to another time zone:

```zig
dt = try dt.tzConvert(zdt.Timezone.UTC);
// 2024-12-23T23:00:00+00:00
```

## Tools

(TODO)

### string parsing, string generation

Available and planned directives (%-prefixed codes), as of v0.1.22:

| Directive | zdt: parse | zdt: format | Meaning                                                                                                                                                                          | Example                                                                      |
| :-------- | :--------- | :---------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------- | -------------------------------------------------------- |
| %a        |            | ✔          | Weekday as locale’s abbreviated name.                                                                                                                                            | Sun, Mon, …, Sat (en_US); So, Mo, …, Sa (de_DE)                              |
| %A        |            | ✔          | Weekday as locale’s full name.                                                                                                                                                   | Sunday, Monday, …, Saturday (en_US); Sonntag, Montag, …, Samstag (de_DE)     |
| %w        |            |             | Weekday as a decimal number, where 0 is Sunday and 6 is Saturday.                                                                                                                | 0, 1, …, 6                                                                   |
| %d        | ✔         | ✔          | Day of the month as a zero-padded decimal number.                                                                                                                                | 01, 02, …, 31                                                                |
| %b        |            | ✔          | Month as locale’s abbreviated name.                                                                                                                                              | Jan, Feb, …, Dec (en_US); Jan, Feb, …, Dez (de_DE)                           |
| %B        |            | ✔          | Month as locale’s full name.                                                                                                                                                     | January, February, …, December (en_US); Januar, Februar, …, Dezember (de_DE) |
| %m        | ✔         | ✔          | Month as a zero-padded decimal number.                                                                                                                                           | 01, 02, …, 12                                                                |
| %y        |            |             | Year without century as a zero-padded decimal number.                                                                                                                            | 00, 01, …, 99                                                                |
| %Y        | ✔         | ✔          | Year with century as a decimal number.                                                                                                                                           | 0001, 0002, …, 2013, 2014, …, 9998, 9999                                     |
| %H        | ✔         | ✔          | Hour (24-hour clock) as a zero-padded decimal number.                                                                                                                            | 00, 01, …, 23                                                                |
| %I        |            |             | Hour (12-hour clock) as a zero-padded decimal number.                                                                                                                            | 01, 02, …, 12                                                                |
| %p        |            |             | Locale’s equivalent of either AM or PM.                                                                                                                                          | AM, PM (en_US); am, pm (de_DE)                                               |
| %M        | ✔         | ✔          | Minute as a zero-padded decimal number.                                                                                                                                          | 00, 01, …, 59                                                                |
| %S        | ✔         | ✔          | Second as a zero-padded decimal number.                                                                                                                                          | 00, 01, …, 60                                                                |
| %f        | ✔         | ✔          | Nanosecond as a decimal number, zero-padded to 9 digits.                                                                                                                         | 000000000, 000000001, …, 999999999                                           |
| %z        | ✔         | ✔          | UTC offset in the form (+                                                                                                                                                        | -)hh[:mm[:ss]]. Naive datetime gives empty string.                           | (empty), +0000, +01:00, -0400, +1030, +063415, -03:07:12 |
| %Z        |            | ✔          | Time zone abbreviation. Naive datetime gives empty string.                                                                                                                       | (empty), UTC, Z                                                              |
| %i        |            |             | IANA time zone identifier. Gives empty string if not defined for given datetime.                                                                                                 | Europe/Berlin, Asia/Kolkata                                                  |
| %j        |            |             | Day of the year as a zero-padded decimal number.                                                                                                                                 | 001, 002, …, 366                                                             |
| %U        |            |             | Week number of the year (Sunday as the first day of the week) as a zero-padded decimal number. All days in a new year preceding the first Sunday are considered to be in week 0. | 00, 01, …, 53                                                                |
| %W        |            |             | Week number of the year (Monday as the first day of the week) as a zero-padded decimal number. All days in a new year preceding the first Monday are considered to be in week 0. | 00, 01, …, 53                                                                |
| %G        |            |             | ISO 8601 year with century representing the year that contains the greater part of the ISO week (%V).                                                                            | 0001, 0002, …, 2013, 2014, …, 9998, 9999                                     |
| %u        |            |             | ISO 8601 weekday as a decimal number where 1 is Monday.                                                                                                                          | 1, 2, …, 7                                                                   |
| %V        |            |             | ISO 8601 week as a decimal number with Monday as the first day of the week. Week 01 is the week containing Jan 4.                                                                | 01, 02, …, 53                                                                |
| %T        |            |             | ISO 8601 date and time with optional fractional seconds (if not zero) and UTC offset (if time zone / UTC offset defined)                                                         | 2022-08-01T12:24:19.008993841+02:00                                          |
| %c        |            |             | Locale’s appropriate date and time representation.                                                                                                                               | Tue Aug 16 21:30:00 1988 (en_US); Di 16 Aug 21:30:00 1988 (de_DE)            |
| %x        |            |             | Locale’s appropriate date representation.                                                                                                                                        | 08/16/88 (None); 08/16/1988 (en_US); 16.08.1988 (de_DE)                      |
| %X        |            |             | Locale’s appropriate time representation.                                                                                                                                        | 21:30:00 (en_US); 21:30:00 (de_DE)                                           |
| %%        | ✔         | ✔          | A literal '%' character.                                                                                                                                                         | %                                                                            |

### calendric calculations
