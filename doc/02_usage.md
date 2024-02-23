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

### calendric calculations
