const std = @import("std");
const bj = @import("bj.zig");

pub fn main() !u8 {
    const default_card = bj.Card{
        .value = 0,
        .suit = 0,
    };

    var cards_array = [_]bj.Card{default_card} ** (bj.CARDS_PER_DECK * bj.MAX_DECKS);
    const shoe = bj.Shoe{
        .num_cards = 0,
        .cards = &cards_array,
        .current_card = undefined,
    };

    const dealer_hand = bj.DealerHand{
        .hand = undefined,
        .hide_down_card = true,
    };

    const player_hand = bj.PlayerHand{
        .hand = undefined,
        .bet = 0,
        .stood = false,
        .played = false,
        .paid = false,
        .status = bj.HandStatus.Won,
    };

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

    const stdin = std.io.getStdIn();
    try bj.buffer_off(&stdin);

    try bj.load_game(&game);
    try bj.initPrng();

    while (!game.quitting) {
        try bj.deal_new_hand(&game);
    }

    try bj.buffer_on(&stdin);

    return 0;
}
