const std = @import("std");
const print = std.debug.print;

const zdt = @import("zdt");
const dt = zdt.datetime;
const tz = zdt.tz;
const dtstr = zdt.str;

test "datetime demo" {
    print("\n---> datetime demo", .{});

    print("\n datetime type info:", .{});
    print("size of {s}: {}\n", .{ @typeName(dt.Datetime), @sizeOf(dt.Datetime) });
    inline for (std.meta.fields(dt.Datetime)) |field| {
        std.debug.print("  field {s} byte offset: {}\n", .{ field.name, @offsetOf(dt.Datetime, field.name) });
    }

    print("\n---> (usage) Unix epoch: datetime from timestamp", .{});
    const unix_epoch = try dt.Datetime.fromUnix(0, dt.Unit.second, null);
    print("\n'Unix epoch', naive datetime : {s}\n", .{unix_epoch});
    const unix_epoch_correct = try dt.Datetime.fromUnix(0, dt.Unit.second, tz.UTC);
    print("'Unix epoch', aware datetime : {s}\n", .{unix_epoch_correct});
    print("'Unix epoch', tz name : {s}\n", .{unix_epoch_correct.tzinfo.?.name});

    print("\n---> (usage) Now: datetime from system time", .{});
    const now = dt.Datetime.utcnow();
    print("\n'now', UTC      : {s}\n", .{now});
    const now_s = try now.floorTo(dt.Timespan.second);
    print("(nanos removed) : {s}\n", .{now_s});
    const now_date = try now.floorTo(dt.Timespan.day);
    print("         (date) : {s}\n", .{now_date});
}
