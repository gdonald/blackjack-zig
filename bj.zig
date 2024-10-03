const std = @import("std");

pub const CARDS_PER_DECK: u16 = 52;
pub const MAX_DECKS: u16 = 8;
pub const MAX_CARDS_PER_HAND: u8 = 11;
pub const MAX_PLAYER_HANDS: u8 = 7;
pub const MIN_BET: u32 = 500;
pub const MAX_BET: u32 = 10000000;
pub const SAVE_FILE: []const u8 = "bj.txt";

pub const Card = struct {
    value: u8,
    suit: u8,
};

pub const Shoe = struct {
    cards: []Card,
    current_card: u16,
    num_cards: u16,
};

pub const Hand = struct {
    cards: [MAX_CARDS_PER_HAND]Card,
    num_cards: u8,
};

pub const DealerHand = struct {
    hand: Hand,
    hide_down_card: bool,
};

const CountMethod = enum {
    Soft,
    Hard,
};

pub const HandStatus = enum(u8) {
    Unknown = 0,
    Won,
    Lost,
    Push,
};

pub const PlayerHand = struct {
    hand: Hand,
    bet: u32,
    stood: bool,
    played: bool,
    paid: bool,
    status: HandStatus,
};

pub const Game = struct {
    shoe: Shoe,
    dealer_hand: DealerHand,
    player_hands: [MAX_PLAYER_HANDS]PlayerHand,
    num_decks: u8,
    deck_type: u8,
    face_type: u8,
    money: u128,
    current_bet: u32,
    current_player_hand: u8,
    total_player_hands: u8,
    quitting: bool,
    shuffle_specs: *const [8][2]u8,
    faces: *const [4]*const u8,
    faces2: *const [4]*const u8,
};

pub const shuffle_specs: [8][2]u8 = [8][2]u8{
    [2]u8{ 95, 8 },
    [2]u8{ 92, 7 },
    [2]u8{ 89, 6 },
    [2]u8{ 86, 5 },
    [2]u8{ 84, 4 },
    [2]u8{ 82, 3 },
    [2]u8{ 81, 2 },
    [2]u8{ 80, 1 },
};

pub const faces: [14][4][]const u8 = [14][4][]const u8{
    [4][]const u8{ "A♠", "A♥", "A♣", "A♦" },
    [4][]const u8{ "2♠", "2♥", "2♣", "2♦" },
    [4][]const u8{ "3♠", "3♥", "3♣", "3♦" },
    [4][]const u8{ "4♠", "4♥", "4♣", "4♦" },
    [4][]const u8{ "5♠", "5♥", "5♣", "5♦" },
    [4][]const u8{ "6♠", "6♥", "6♣", "6♦" },
    [4][]const u8{ "7♠", "7♥", "7♣", "7♦" },
    [4][]const u8{ "8♠", "8♥", "8♣", "8♦" },
    [4][]const u8{ "9♠", "9♥", "9♣", "9♦" },
    [4][]const u8{ "T♠", "T♥", "T♣", "T♦" },
    [4][]const u8{ "J♠", "J♥", "J♣", "J♦" },
    [4][]const u8{ "Q♠", "Q♥", "Q♣", "Q♦" },
    [4][]const u8{ "K♠", "K♥", "K♣", "K♦" },
    [4][]const u8{ "??", "", "", "" },
};

pub const faces2: [14][4][]const u8 = [14][4][]const u8{
    [4][]const u8{ "🂡", "🂱", "🃁", "🃑" },
    [4][]const u8{ "🂢", "🂲", "🃂", "🃒" },
    [4][]const u8{ "🂣", "🂳", "🃃", "🃓" },
    [4][]const u8{ "🂤", "🂴", "🃄", "🃔" },
    [4][]const u8{ "🂥", "🂵", "🃅", "🃕" },
    [4][]const u8{ "🂦", "🂶", "🃆", "🃖" },
    [4][]const u8{ "🂧", "🂷", "🃇", "🃗" },
    [4][]const u8{ "🂨", "🂸", "🃈", "🃘" },
    [4][]const u8{ "🂩", "🂹", "🃉", "🃙" },
    [4][]const u8{ "🂪", "🂺", "🃊", "🃚" },
    [4][]const u8{ "🂫", "🂻", "🃋", "🃛" },
    [4][]const u8{ "🂭", "🂽", "🃍", "🃝" },
    [4][]const u8{ "🂮", "🂾", "🃎", "🃞" },
    [4][]const u8{ "🂠", "", "", "" },
};

fn get_total_cards(game: *Game) u32 {
    return game.num_decks * CARDS_PER_DECK;
}

fn swap(a: *Card, b: *Card) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

fn myrand(min: u32, max: u32) !u32 {
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.rand.DefaultPrng.init(seed);
    const rand = prng.random();

    return rand.intRangeAtMost(u32, min, max);
}

fn shuffle(shoe: *Shoe) !void {
    for (0..7) |_| {
        var i = shoe.num_cards - 1;
        while (i > 0) : (i -= 1) {
            const rand_idx = try myrand(0, shoe.num_cards - 1);
            swap(&shoe.cards[i], &shoe.cards[rand_idx]);
        }
    }
    shoe.current_card = 0;
}

pub fn new_shoe(game: *Game, values: []const u8, values_count: u32) !void {
    const total_cards = get_total_cards(game);
    game.shoe.num_cards = 0;
    const suites: [4]u8 = [4]u8{ 0, 1, 2, 3 };

    while (game.shoe.num_cards < total_cards) {
        for (suites) |suit| {
            if (game.shoe.num_cards >= total_cards) {
                break;
            }

            for (0..values_count) |value_count| {
                if (game.shoe.num_cards >= total_cards) {
                    break;
                }

                const c = Card{ .suit = suit, .value = values[value_count] };
                game.shoe.cards[game.shoe.num_cards] = c;
                game.shoe.num_cards += 1;
            }
        }
    }

    try shuffle(&game.shoe);
}

pub fn need_to_shuffle(game: *const Game) bool {
    if (game.shoe.num_cards == 0) {
        return true;
    }

    const current_card: f64 = @as(f64, @floatFromInt(game.shoe.current_card));
    const num_cards: f64 = @as(f64, @floatFromInt(game.shoe.num_cards));
    const ratio: f64 = current_card / num_cards * 100.0;
    const used: u32 = @as(u32, @intFromFloat(ratio));

    for (0..MAX_DECKS) |x| {
        if (game.num_decks == game.shuffle_specs[x][1] and used > game.shuffle_specs[x][0]) {
            return true;
        }
    }

    return false;
}

pub fn new_regular(game: *Game) !void {
    const values = [13]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    try new_shoe(game, &values, 13);
}

pub fn build_new_shoe(game: *Game) !void {
    // switch (game.deck_type) {
    //     2 => {
    //         new_aces(game);
    //     },
    //     3 => {
    //         new_jacks(game);
    //     },
    //     4 => {
    //         new_aces_jacks(game);
    //     },
    //     5 => {
    //         new_sevens(game);
    //     },
    //     6 => {
    //         new_eights(game);
    //     },
    //     else => {
    try new_regular(game);
    //     },
    // }
}

pub fn deal_card(shoe: *Shoe, hand: *Hand) void {
    hand.cards[hand.num_cards] = shoe.cards[shoe.current_card];
    hand.num_cards += 1;
    shoe.current_card += 1;
}

pub fn deal_new_hand(game: *Game) !void {
    var player_hand = PlayerHand{
        .hand = Hand{
            .cards = [_]Card{Card{ .value = 0, .suit = 0 }} ** MAX_CARDS_PER_HAND,
            .num_cards = 0,
        },
        .bet = game.current_bet,
        .stood = false,
        .played = false,
        .paid = false,
        .status = HandStatus.Unknown,
    };
    var dealer_hand = &game.dealer_hand;
    const shoe = &game.shoe;

    if (need_to_shuffle(game)) {
        try build_new_shoe(game);
    }

    dealer_hand.hide_down_card = true;
    dealer_hand.hand.num_cards = 0;

    deal_card(shoe, &player_hand.hand);
    deal_card(shoe, &dealer_hand.hand);
    deal_card(shoe, &player_hand.hand);
    deal_card(shoe, &dealer_hand.hand);

    game.player_hands[0] = player_hand;
    game.current_player_hand = 0;
    game.total_player_hands = 1;

    // if (dealer_upcard_is_ace(dealer_hand) && !is_blackjack(&player_hand.hand)) {
    //     draw_hands(game);
    //     ask_insurance(game);
    //     return;
    // }

    // if (player_is_done(game, &player_hand)) {
    //     dealer_hand.hide_down_card = false;
    //     pay_hands(game);
    //     draw_hands(game);
    //     bet_options(game);
    //     return;
    // }

    // draw_hands(game);
    // player_get_action(game);
    // save_game(game);
}
