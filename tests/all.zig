const std = @import("std");

test {
    _ = @import("bj_test.zig");
    _ = @import("main_test.zig");
    _ = @import("io_test.zig");
    std.testing.refAllDecls(@import("main"));
}
