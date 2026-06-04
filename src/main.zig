const std = @import("std");
const bj = @import("bj");

pub fn main() !u8 {
    var game = bj.Game.init();

    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();

    var stdin_file = std.Io.File.stdin();
    var in_buffer: [64]u8 = undefined;
    var stdin_reader = stdin_file.reader(io, &in_buffer);

    var stdout_file = std.Io.File.stdout();
    var out_buffer: [4096]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &out_buffer);

    game.io = io;
    game.in = &stdin_reader.interface;
    game.out = &stdout_writer.interface;
    game.raw_tty = stdin_file;

    try bj.run_game(&game);

    return 0;
}
