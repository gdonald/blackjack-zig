const std = @import("std");
const testing = std.testing;
const bj = @import("bj");

// main() opens raw terminal mode and loops on stdin, so it cannot run
// headless. What it contributes is the starting Game it hands to run_game,
// so that initial state is what these tests pin down.

test "a fresh game starts with the table defaults" {
    const game = bj.Game.init();

    try testing.expectEqual(@as(u128, 10000), game.money);
    try testing.expectEqual(@as(u32, 500), game.current_bet);
    try testing.expectEqual(@as(u8, 1), game.num_decks);
    try testing.expectEqual(@as(u8, 0), game.deck_type);
    try testing.expectEqual(@as(u8, 0), game.face_type);
}

test "a fresh game has no hands dealt and is not quitting" {
    const game = bj.Game.init();

    try testing.expectEqual(@as(u8, 0), game.total_player_hands);
    try testing.expectEqual(@as(u8, 0), game.current_player_hand);
    try testing.expect(!game.quitting);
}
