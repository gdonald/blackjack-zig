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
    Won = 1,
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
    shuffle_specs: *const [2]u8,
    faces: *const [4]*const u8,
    faces2: *const [4]*const u8,
};

const shuffle_specs: [8][2]u8 = [8][2]u8{
    [2]u8{ 95, 8 },
    [2]u8{ 92, 7 },
    [2]u8{ 89, 6 },
    [2]u8{ 86, 5 },
    [2]u8{ 84, 4 },
    [2]u8{ 82, 3 },
    [2]u8{ 81, 2 },
    [2]u8{ 80, 1 },
};

const faces: [14][4][]const u8 = [14][4][]const u8{
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

const faces2: [14][4][]const u8 = [14][4][]const u8{
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

pub fn new_shoe(game: *Game, values: []const u8, values_count: u32) void {
    const total_cards = 52; // get_total_cards(game);
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

    // shuffle(&game.shoe);
}
