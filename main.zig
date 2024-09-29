const std = @import("std");
const bj = @import("bj.zig");

usingnamespace bj;

pub fn main() void {
    const default_card = bj.Card{ .value = 0, .suit = 0 };
    var cards_array = [_]bj.Card{default_card} ** (bj.CARDS_PER_DECK * bj.MAX_DECKS);
    const shoe = bj.Shoe{ .num_cards = 0, .cards = &cards_array, .current_card = undefined };

    const dealer_hand = bj.DealerHand{ .hand = undefined, .hide_down_card = true };

    const player_hand = bj.PlayerHand{ .hand = undefined, .bet = 0, .stood = false, .played = false, .paid = false, .status = bj.HandStatus.Won };
    const player_hands = [bj.MAX_PLAYER_HANDS]bj.PlayerHand{ player_hand, undefined, undefined, undefined, undefined, undefined, undefined };

    var game = bj.Game{ .shoe = shoe, .dealer_hand = dealer_hand, .player_hands = player_hands, .num_decks = 0, .deck_type = 0, .face_type = 0, .money = 0, .current_bet = 0, .current_player_hand = 0, .total_player_hands = 0, .quitting = false, .shuffle_specs = undefined, .faces = undefined, .faces2 = undefined };

    const values = [13]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    bj.new_shoe(&game, &values, 13);

    for (0..game.shoe.num_cards) |i| {
        const card = game.shoe.cards[i];
        std.debug.print("suit: {d} value: {d}\n", .{ card.suit, card.value });
    }
}
