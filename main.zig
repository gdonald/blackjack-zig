const std = @import("std");
const bj = @import("bj.zig");

pub fn main() !u8 {
    var game = bj.Game.init();
    try bj.run_game(&game);

    return 0;
}
