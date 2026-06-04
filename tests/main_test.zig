const std = @import("std");
const testing = std.testing;
const bj = @import("bj");

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
