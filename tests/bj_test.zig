const std = @import("std");
const testing = std.testing;
const bj = @import("bj");

const Card = bj.Card;
const Hand = bj.Hand;
const PlayerHand = bj.PlayerHand;
const DealerHand = bj.DealerHand;
const Game = bj.Game;
const HandStatus = bj.HandStatus;

fn make_card(value: u8, suit: u8) Card {
    return Card{ .value = value, .suit = suit };
}

fn make_player_hand(cards: []const Card) PlayerHand {
    var player_hand = PlayerHand.init();
    player_hand.hand.num_cards = 0;
    for (cards) |card| {
        player_hand.hand.cards[player_hand.hand.num_cards] = card;
        player_hand.hand.num_cards += 1;
    }
    return player_hand;
}

fn make_dealer_hand(cards: []const Card, hide_down_card: bool) DealerHand {
    var dealer_hand = DealerHand.init();
    dealer_hand.hide_down_card = hide_down_card;
    dealer_hand.hand.num_cards = 0;
    for (cards) |card| {
        dealer_hand.hand.cards[dealer_hand.hand.num_cards] = card;
        dealer_hand.hand.num_cards += 1;
    }
    return dealer_hand;
}

fn make_game() Game {
    var game = Game.init();
    game.prng = std.Random.DefaultPrng.init(42);
    return game;
}

test "is_ace recognizes only value zero" {
    try testing.expect(bj.is_ace(&make_card(0, 0)));
    try testing.expect(!bj.is_ace(&make_card(1, 0)));
    try testing.expect(!bj.is_ace(&make_card(12, 0)));
}

test "is_ten recognizes ten through king" {
    try testing.expect(!bj.is_ten(&make_card(8, 0))); // nine
    try testing.expect(bj.is_ten(&make_card(9, 0))); // ten
    try testing.expect(bj.is_ten(&make_card(10, 0))); // jack
    try testing.expect(bj.is_ten(&make_card(12, 0))); // king
}

test "is_blackjack needs exactly an ace and a ten card" {
    const ace_king = make_player_hand(&[_]Card{ make_card(0, 0), make_card(12, 1) });
    try testing.expect(bj.is_blackjack(&ace_king.hand));

    const king_ace = make_player_hand(&[_]Card{ make_card(12, 0), make_card(0, 1) });
    try testing.expect(bj.is_blackjack(&king_ace.hand));

    const ace_nine = make_player_hand(&[_]Card{ make_card(0, 0), make_card(8, 1) });
    try testing.expect(!bj.is_blackjack(&ace_nine.hand));

    const three_cards = make_player_hand(&[_]Card{ make_card(0, 0), make_card(9, 1), make_card(2, 2) });
    try testing.expect(!bj.is_blackjack(&three_cards.hand));
}

test "player_get_value counts an ace as eleven when soft and one when hard" {
    const ace_nine = make_player_hand(&[_]Card{ make_card(0, 0), make_card(8, 1) });
    try testing.expectEqual(@as(u32, 20), bj.player_get_value(&ace_nine, .Soft));
    try testing.expectEqual(@as(u32, 10), bj.player_get_value(&ace_nine, .Hard));
}

test "player_get_value keeps only the first ace soft when two aces" {
    const two_aces = make_player_hand(&[_]Card{ make_card(0, 0), make_card(0, 1) });
    try testing.expectEqual(@as(u32, 12), bj.player_get_value(&two_aces, .Soft));
    try testing.expectEqual(@as(u32, 2), bj.player_get_value(&two_aces, .Hard));
}

test "player_get_value falls back to hard when soft total busts" {
    const ace_six_king = make_player_hand(&[_]Card{ make_card(0, 0), make_card(5, 1), make_card(12, 2) });
    try testing.expectEqual(@as(u32, 17), bj.player_get_value(&ace_six_king, .Soft));
}

test "player_is_busted past twenty one" {
    const busted = make_player_hand(&[_]Card{ make_card(12, 0), make_card(11, 1), make_card(4, 2) });
    try testing.expect(bj.player_is_busted(&busted));

    const twenty = make_player_hand(&[_]Card{ make_card(12, 0), make_card(11, 1) });
    try testing.expect(!bj.player_is_busted(&twenty));
}

test "dealer_get_value skips the hidden down card" {
    const hidden = make_dealer_hand(&[_]Card{ make_card(0, 0), make_card(12, 1) }, true);
    try testing.expectEqual(@as(u32, 11), bj.dealer_get_value(&hidden, .Soft));

    const shown = make_dealer_hand(&[_]Card{ make_card(0, 0), make_card(12, 1) }, false);
    try testing.expectEqual(@as(u32, 21), bj.dealer_get_value(&shown, .Soft));
}

test "dealer_upcard_is_ace reads the first card" {
    const ace_up = make_dealer_hand(&[_]Card{ make_card(0, 0), make_card(12, 1) }, true);
    try testing.expect(bj.dealer_upcard_is_ace(&ace_up));

    const king_up = make_dealer_hand(&[_]Card{ make_card(12, 0), make_card(0, 1) }, true);
    try testing.expect(!bj.dealer_upcard_is_ace(&king_up));
}

test "dealer_is_busted past twenty one" {
    const busted = make_dealer_hand(&[_]Card{ make_card(12, 0), make_card(11, 1), make_card(4, 2) }, false);
    try testing.expect(bj.dealer_is_busted(&busted));
}

test "player_can_hit blocked when hand reaches a hard twenty one" {
    const eleven = make_player_hand(&[_]Card{ make_card(4, 0), make_card(5, 1) });
    try testing.expect(bj.player_can_hit(&eleven));

    const hard_twenty_one = make_player_hand(&[_]Card{ make_card(12, 0), make_card(4, 1), make_card(5, 2) });
    try testing.expect(!bj.player_can_hit(&hard_twenty_one));

    var played = eleven;
    played.played = true;
    try testing.expect(!bj.player_can_hit(&played));
}

test "player_can_stand unless busted or blackjack" {
    const eleven = make_player_hand(&[_]Card{ make_card(4, 0), make_card(5, 1) });
    try testing.expect(bj.player_can_stand(&eleven));

    const busted = make_player_hand(&[_]Card{ make_card(12, 0), make_card(11, 1), make_card(4, 2) });
    try testing.expect(!bj.player_can_stand(&busted));

    const blackjack = make_player_hand(&[_]Card{ make_card(0, 0), make_card(12, 1) });
    try testing.expect(!bj.player_can_stand(&blackjack));
}

test "player_can_split needs a matched pair and enough money" {
    var game = make_game();
    game.money = 10000;
    game.current_player_hand = 0;
    game.total_player_hands = 1;

    var pair = make_player_hand(&[_]Card{ make_card(7, 0), make_card(7, 1) });
    pair.bet = 500;
    game.player_hands[0] = pair;
    try testing.expect(bj.player_can_split(&game));

    var mismatch = make_player_hand(&[_]Card{ make_card(7, 0), make_card(8, 1) });
    mismatch.bet = 500;
    game.player_hands[0] = mismatch;
    try testing.expect(!bj.player_can_split(&game));

    game.player_hands[0] = pair;
    game.money = 600;
    try testing.expect(!bj.player_can_split(&game));
}

test "player_can_dbl needs two cards and enough money" {
    var game = make_game();
    game.money = 10000;
    game.current_player_hand = 0;
    game.total_player_hands = 1;

    var two_cards = make_player_hand(&[_]Card{ make_card(4, 0), make_card(5, 1) });
    two_cards.bet = 500;
    game.player_hands[0] = two_cards;
    try testing.expect(bj.player_can_dbl(&game));

    var three_cards = make_player_hand(&[_]Card{ make_card(4, 0), make_card(5, 1), make_card(1, 2) });
    three_cards.bet = 500;
    game.player_hands[0] = three_cards;
    try testing.expect(!bj.player_can_dbl(&game));

    game.player_hands[0] = two_cards;
    game.money = 600;
    try testing.expect(!bj.player_can_dbl(&game));
}

test "player_is_done returns false when the hand can still be played" {
    var game = make_game();
    game.money = 10000;
    game.current_player_hand = 0;
    game.total_player_hands = 1;

    var playable = make_player_hand(&[_]Card{ make_card(4, 0), make_card(5, 1) });
    playable.bet = 500;
    game.player_hands[0] = playable;

    try testing.expect(!bj.player_is_done(&game, &game.player_hands[0]));
    try testing.expect(!game.player_hands[0].played);
    try testing.expectEqual(@as(u128, 10000), game.money);
}

test "player_is_done marks a busted hand as lost and deducts the bet" {
    var game = make_game();
    game.money = 10000;
    game.current_player_hand = 0;
    game.total_player_hands = 1;

    var busted = make_player_hand(&[_]Card{ make_card(12, 0), make_card(11, 1), make_card(4, 2) });
    busted.bet = 500;
    game.player_hands[0] = busted;

    try testing.expect(bj.player_is_done(&game, &game.player_hands[0]));
    try testing.expect(game.player_hands[0].played);
    try testing.expect(game.player_hands[0].paid);
    try testing.expectEqual(HandStatus.Lost, game.player_hands[0].status);
    try testing.expectEqual(@as(u128, 9500), game.money);
}

test "normalize_bet clamps to the bounds and available money" {
    var game = make_game();
    game.money = 100000000;

    game.current_bet = 100;
    bj.normalize_bet(&game);
    try testing.expectEqual(bj.MIN_BET, game.current_bet);

    game.current_bet = bj.MAX_BET + 1;
    bj.normalize_bet(&game);
    try testing.expectEqual(bj.MAX_BET, game.current_bet);

    game.money = 300;
    game.current_bet = 500;
    bj.normalize_bet(&game);
    try testing.expectEqual(@as(u32, 300), game.current_bet);
}

test "get_total_cards scales with the deck count" {
    var game = make_game();
    game.num_decks = 1;
    try testing.expectEqual(@as(u32, 52), bj.get_total_cards(&game));
    game.num_decks = 2;
    try testing.expectEqual(@as(u32, 104), bj.get_total_cards(&game));
}

test "need_to_shuffle when the shoe is empty" {
    var game = make_game();
    game.shoe.num_cards = 0;
    try testing.expect(bj.need_to_shuffle(&game));

    game.shoe.num_cards = 52;
    game.shoe.current_card = 0;
    try testing.expect(!bj.need_to_shuffle(&game));
}

test "build_new_shoe fills a regular deck and resets the position" {
    var game = make_game();
    game.num_decks = 1;
    game.deck_type = 0;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 52), game.shoe.num_cards);
    try testing.expectEqual(@as(u16, 0), game.shoe.current_card);
}

test "build_new_shoe with the aces deck holds only aces" {
    var game = make_game();
    game.num_decks = 8;
    game.deck_type = 2;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 416), game.shoe.num_cards);
    for (game.shoe.cards[0..game.shoe.num_cards]) |card| {
        try testing.expectEqual(@as(u8, 0), card.value);
    }
}

test "deal_card advances the shoe and grows the hand" {
    var game = make_game();
    game.num_decks = 1;
    game.deck_type = 0;
    try bj.build_new_shoe(&game);

    var hand = Hand{ .cards = undefined, .num_cards = 0 };
    bj.deal_card(&game.shoe, &hand);
    try testing.expectEqual(@as(u8, 1), hand.num_cards);
    try testing.expectEqual(@as(u16, 1), game.shoe.current_card);
}

test "build_new_shoe with the jacks deck holds only jacks" {
    var game = make_game();
    game.num_decks = 8;
    game.deck_type = 3;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 416), game.shoe.num_cards);
    for (game.shoe.cards[0..game.shoe.num_cards]) |card| {
        try testing.expectEqual(@as(u8, 10), card.value);
    }
}

test "build_new_shoe with the aces and jacks deck holds only aces and jacks" {
    var game = make_game();
    game.num_decks = 8;
    game.deck_type = 4;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 416), game.shoe.num_cards);
    for (game.shoe.cards[0..game.shoe.num_cards]) |card| {
        try testing.expect(card.value == 0 or card.value == 10);
    }
}

test "build_new_shoe with the sevens deck holds only sevens" {
    var game = make_game();
    game.num_decks = 8;
    game.deck_type = 5;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 416), game.shoe.num_cards);
    for (game.shoe.cards[0..game.shoe.num_cards]) |card| {
        try testing.expectEqual(@as(u8, 6), card.value);
    }
}

test "build_new_shoe with the eights deck holds only eights" {
    var game = make_game();
    game.num_decks = 8;
    game.deck_type = 6;
    try bj.build_new_shoe(&game);

    try testing.expectEqual(@as(u16, 416), game.shoe.num_cards);
    for (game.shoe.cards[0..game.shoe.num_cards]) |card| {
        try testing.expectEqual(@as(u8, 7), card.value);
    }
}

test "get_card_face switches on the face type" {
    var game = make_game();
    game.face_type = 0;
    try testing.expectEqualStrings("A♠", bj.get_card_face(&game, 0, 0));
    game.face_type = 2;
    try testing.expectEqualStrings("🂡", bj.get_card_face(&game, 0, 0));
}
