const std = @import("std");
const bj = @import("bj.zig");

pub fn main() !u8 {
    try bj.initPrng();

    const shoe = bj.Shoe.init();
    const dealer_hand = bj.DealerHand.init();
    const player_hand = bj.PlayerHand.init();

    const player_hands = [bj.MAX_PLAYER_HANDS]bj.PlayerHand{
        player_hand,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
    };

    var game = bj.Game{
        .shoe = shoe,
        .dealer_hand = dealer_hand,
        .player_hands = player_hands,
        .num_decks = 1,
        .deck_type = 0,
        .face_type = 0,
        .money = 10000,
        .current_bet = 500,
        .current_player_hand = 0,
        .total_player_hands = 0,
        .quitting = false,
        .shuffle_specs = &bj.shuffle_specs,
        .faces = &bj.faces,
        .faces2 = &bj.faces2,
    };

    try bj.load_game(&game);

    const stdin = std.io.getStdIn();
    try bj.buffer_off(&stdin);

    while (!game.quitting) {
        try bj.deal_new_hand(&game);
    }

    try bj.buffer_on(&stdin);

    return 0;
}
