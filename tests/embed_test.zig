const std = @import("std");
const print = std.debug.print;

const zdt = @import("zdt");
const zi = @import("zoneinfo");

test "import zdt" {
    print("\n{any}", .{zdt.Timezone.UTC});
}

test "import zi" {
    print("\n{any}", .{zi.tzfiles});
}
