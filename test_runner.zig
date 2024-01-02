// modified based on https://gist.github.com/nurpax/4afcb6e4ef3f03f0d282f7c462005f12

const std = @import("std");
const builtin = @import("builtin");

const BORDER = "=" ** 80;

const Status = enum {
    pass,
    fail,
    skip,
    text,

    pub fn code(self: Status) []const u8 {
        return switch (self) {
            .fail => "\x1b[31m",
            .pass => "\x1b[32m",
            .skip => "\x1b[33m",
            .text => "\x1b[0m",
        };
    }
};

fn getenvOwned(alloc: std.mem.Allocator, key: []const u8) ?[]u8 {
    const v = std.process.getEnvVarOwned(alloc, key) catch |err| {
        if (err == error.EnvironmentVariableNotFound) {
            return null;
        }
        std.log.warn("failed to get env var {s} due to err {}", .{ key, err });
        return null;
    };
    return v;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
    const alloc = gpa.allocator();
    const fail_first = blk: {
        if (getenvOwned(alloc, "TEST_FAIL_FIRST")) |e| {
            defer alloc.free(e);
            break :blk std.mem.eql(u8, e, "true");
        }
        break :blk false;
    };
    const filter = getenvOwned(alloc, "TEST_FILTER");
    defer if (filter) |f| alloc.free(f);

    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());
    var printer = buf.writer();

    //    printer.fmt("\r\x1b[0K", .{}); // beginning of line and clear to end of line

    var pass: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;

    try printer.print("\x1b[36m{s}\x1b[0m\n", .{BORDER});

    for (builtin.test_functions) |t| {
        std.testing.allocator_instance = .{};
        var status = Status.pass;

        if (filter) |f| {
            if (std.mem.indexOf(u8, t.name, f) == null) {
                continue;
            }
        }

        const test_name = t.name[5..];

        try printer.print("Testing {s}: ", .{test_name});

        const result = t.func();

        if (std.testing.allocator_instance.deinit() == .leak) {
            leak += 1;
            try printer.print("\n{s}{s}\n\"{s}\" - Memory Leak\n{s}{s}\n", .{
                Status.fail.code(),
                BORDER,
                test_name,
                BORDER,
                Status.text.code(),
            });
        }

        if (result) |_| {
            pass += 1;
        } else |err| {
            switch (err) {
                error.SkipZigTest => {
                    skip += 1;
                    status = .skip;
                },
                else => {
                    status = .fail;
                    fail += 1;
                    try printer.print("\n{s}{s}\n\"{s}\" - {s}\n{s}{s}\n", .{
                        Status.fail.code(),
                        BORDER,
                        test_name,
                        @errorName(err),
                        BORDER,
                        Status.text.code(),
                    });
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    if (fail_first) {
                        break;
                    }
                },
            }
        }

        try printer.print("{s}[{s}]{s}\n", .{ status.code(), @tagName(status), Status.text.code() });
    }

    const total_tests = pass + fail;
    const status: Status = if (fail == 0) .pass else .fail;
    try printer.print("\x1b[34m{s}\x1b[0m\n", .{BORDER});
    try printer.print("{s}{d} of {d} test{s} passed{s}\n", .{
        status.code(),
        pass,
        total_tests,
        if (total_tests != 1) "s" else "",
        Status.text.code(),
    });
    if (skip > 0) {
        try printer.print("{s}{d} test{s} skipped{s}\n", .{
            status.code(),
            skip,
            if (skip != 1) "s" else "",
            Status.text.code(),
        });
    }
    if (leak > 0) {
        try printer.print("{s}{d} test{s} leaked{s}\n", .{
            status.code(),
            leak,
            if (leak != 1) "s" else "",
            Status.text.code(),
        });
    }
    try printer.print("\x1b[34m{s}\x1b[0m\n\n", .{BORDER});
    try buf.flush(); // catch @panic("flush failed ?!");
    std.os.exit(if (fail == 0) 0 else 1);
}
