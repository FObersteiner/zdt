const std = @import("std");
const print = std.debug.print;

const zdt = @import("zdt");

const dt = zdt.datetime;
const tz = zdt.timezone;
const str = zdt.stringIO;
const dur = zdt.Duration;

test "datetime demo" {
    print("\n---> datetime demo", .{});

    print("\n datetime type info:", .{});
    print("size of {s}: {}\n", .{ @typeName(dt.Datetime), @sizeOf(dt.Datetime) });
    inline for (std.meta.fields(dt.Datetime)) |field| {
        std.debug.print("  field {s} byte offset: {}\n", .{ field.name, @offsetOf(dt.Datetime, field.name) });
    }

    print("\n---> (usage) Unix epoch: datetime from timestamp", .{});
    const unix_epoch = try dt.Datetime.fromUnix(0, dur.Resolution.second, null);
    print("\n'Unix epoch', naive datetime : {s}\n", .{unix_epoch});
    const unix_epoch_correct = try dt.Datetime.fromUnix(0, dur.Resolution.second, tz.UTC);
    print("'Unix epoch', aware datetime : {s}\n", .{unix_epoch_correct});
    print("'Unix epoch', tz name : {s}\n", .{unix_epoch_correct.tzinfo.?.name});

    print("\n---> (usage) Now: datetime from system time", .{});
    const now = dt.Datetime.utcnow();
    print("\n'now', UTC      : {s}\n", .{now});
    const now_s = try now.floorTo(dur.Timespan.second);
    print("(nanos removed) : {s}\n", .{now_s});
    const now_date = try now.floorTo(dur.Timespan.day);
    print("         (date) : {s}\n", .{now_date});

    print("\n---> (usage) ISO8601: parse some allowed formats", .{});
    const date_only = "2014-08-23";
    var parsed = try str.parseISO8601(date_only);
    print("\nparsed '{s}' to {s}", .{ date_only, parsed });

    const datetime_with_frac = "2014-08-23 12:15:56,1234";
    parsed = try str.parseISO8601(datetime_with_frac);
    print("\nparsed '{s}' to {s}", .{ datetime_with_frac, parsed });

    const leap_datetime = "2016-12-31T23:59:60Z";
    parsed = try str.parseISO8601(leap_datetime);
    print("\nparsed '{s}' to {s}\n", .{ leap_datetime, parsed });
}
