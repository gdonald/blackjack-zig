const std = @import("std");

const CARDS_PER_DECK: u16 = 52;
const MAX_DECKS: u16 = 8;
const MAX_CARDS_PER_HAND: u8 = 11;
const MAX_PLAYER_HANDS: u8 = 7;
pub const MIN_BET: u32 = 500;
pub const MAX_BET: u32 = 10000000;
const SAVE_FILE: []const u8 = "bj.txt";

pub const CountMethod = enum {
    Soft,
    Hard,
};

pub const HandStatus = enum(u8) {
    Unknown = 0,
    Won,
    Lost,
    Push,
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

pub const Card = struct {
    value: u8,
    suit: u8,

    fn init(value: u8, suit: u8) Card {
        return Card{ .value = value, .suit = suit };
    }

    fn new() Card {
        return Card{ .value = 0, .suit = 0 };
    }
};

const Shoe = struct {
    cards: [CARDS_PER_DECK * MAX_DECKS]Card,
    current_card: u16,
    num_cards: u16,

    fn init() Shoe {
        return Shoe{
            .num_cards = 0,
            .cards = [_]Card{Card.new()} ** (CARDS_PER_DECK * MAX_DECKS),
            .current_card = undefined,
        };
    }
};

pub const Hand = struct {
    cards: [MAX_CARDS_PER_HAND]Card,
    num_cards: u8,
};

pub const DealerHand = struct {
    hand: Hand,
    hide_down_card: bool,

    pub fn init() DealerHand {
        return DealerHand{
            .hand = undefined,
            .hide_down_card = true,
        };
    }
};

pub const PlayerHand = struct {
    hand: Hand,
    bet: u32,
    stood: bool,
    played: bool,
    paid: bool,
    status: HandStatus,

    pub fn init() PlayerHand {
        return PlayerHand{
            .hand = undefined,
            .bet = 0,
            .stood = false,
            .played = false,
            .paid = false,
            .status = HandStatus.Won,
        };
    }
};

pub const Game = struct {
    io: std.Io,
    in: *std.Io.Reader,
    out: *std.Io.Writer,
    raw_tty: ?std.Io.File,
    eof: bool,
    prng: std.Random.DefaultPrng,
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
    faces: *const [14][4][]const u8,
    faces2: *const [14][4][]const u8,

    pub fn init() Game {
        const shoe = Shoe.init();
        const dealer_hand = DealerHand.init();
        const player_hand = PlayerHand.init();

        const player_hands = [MAX_PLAYER_HANDS]PlayerHand{
            player_hand,
            undefined,
            undefined,
            undefined,
            undefined,
            undefined,
            undefined,
        };

        return Game{
            .io = undefined,
            .in = undefined,
            .out = undefined,
            .raw_tty = null,
            .eof = false,
            .prng = undefined,
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
            .shuffle_specs = &shuffle_specs,
            .faces = &faces,
            .faces2 = &faces2,
        };
    }
};

pub fn run_game(game: *Game) !void {
    init_prng(game);
    try load_game(game);

    if (game.raw_tty) |tty| try buffer_off(&tty);

    while (!game.quitting and !game.eof) {
        try deal_new_hand(game);
    }

    if (game.raw_tty) |tty| try buffer_on(&tty);
    game.out.flush() catch {};
}

pub fn init_prng(game: *Game) void {
    var seed: u64 = undefined;
    game.io.random(std.mem.asBytes(&seed));
    game.prng = std.Random.DefaultPrng.init(seed);
}

fn print(game: *const Game, comptime fmt: []const u8, args: anytype) void {
    game.out.print(fmt, args) catch {};
}

fn read_byte(game: *Game) ?u8 {
    game.out.flush() catch {};
    return game.in.takeByte() catch {
        game.eof = true;
        return null;
    };
}

pub fn get_total_cards(game: *Game) u32 {
    return game.num_decks * CARDS_PER_DECK;
}

fn swap(a: *Card, b: *Card) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

fn myrand(game: *Game, min: u32, max: u32) !u32 {
    return game.prng.random().intRangeAtMost(u32, min, max);
}

fn shuffle(game: *Game) !void {
    for (0..7) |_| {
        var i = game.shoe.num_cards - 1;
        while (i > 0) : (i -= 1) {
            const rand_idx = try myrand(game, 0, game.shoe.num_cards - 1);
            swap(&game.shoe.cards[i], &game.shoe.cards[rand_idx]);
        }
    }
    game.shoe.current_card = 0;
}

fn new_shoe(game: *Game, values: []const u8, values_count: u32) !void {
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

                const card = Card{ .suit = suit, .value = values[value_count] };
                game.shoe.cards[game.shoe.num_cards] = card;
                game.shoe.num_cards += 1;
            }
        }
    }

    try shuffle(game);
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

fn new_regular(game: *Game) !void {
    const values = [13]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    try new_shoe(game, &values, 13);
}

fn new_aces(game: *Game) !void {
    const values: [1]u8 = [1]u8{0};
    try new_shoe(game, &values, 1);
}

fn new_jacks(game: *Game) !void {
    const values: [1]u8 = [1]u8{10};
    try new_shoe(game, &values, 1);
}

fn new_aces_jacks(game: *Game) !void {
    const values: [2]u8 = [2]u8{ 0, 10 };
    try new_shoe(game, &values, 2);
}

fn new_sevens(game: *Game) !void {
    const values: [1]u8 = [1]u8{6};
    try new_shoe(game, &values, 1);
}

fn new_eights(game: *Game) !void {
    const values: [1]u8 = [1]u8{7};
    try new_shoe(game, &values, 1);
}

pub fn build_new_shoe(game: *Game) !void {
    switch (game.deck_type) {
        2 => {
            try new_aces(game);
        },
        3 => {
            try new_jacks(game);
        },
        4 => {
            try new_aces_jacks(game);
        },
        5 => {
            try new_sevens(game);
        },
        6 => {
            try new_eights(game);
        },
        else => {
            try new_regular(game);
        },
    }
}

pub fn deal_card(shoe: *Shoe, hand: *Hand) void {
    hand.cards[hand.num_cards] = shoe.cards[shoe.current_card];
    hand.num_cards += 1;
    shoe.current_card += 1;
}

pub fn is_ace(card: *const Card) bool {
    return card.value == 0;
}

pub fn is_ten(card: *const Card) bool {
    return card.value > 8;
}

pub fn dealer_upcard_is_ace(dealer_hand: *const DealerHand) bool {
    return is_ace(&dealer_hand.hand.cards[0]);
}

pub fn is_blackjack(hand: *const Hand) bool {
    if (hand.num_cards != 2) {
        return false;
    }

    if (is_ace(&hand.cards[0]) and is_ten(&hand.cards[1])) {
        return true;
    }

    return is_ace(&hand.cards[1]) and is_ten(&hand.cards[0]);
}

pub fn get_card_face(game: *const Game, value: u8, suit: u8) []const u8 {
    if (game.face_type == 2) {
        return game.faces2[value][suit];
    }
    return game.faces[value][suit];
}

pub fn dealer_get_value(dealer_hand: *const DealerHand, method: CountMethod) u32 {
    var v: u32 = 0;
    var total: u32 = 0;
    var tmp_v: u32 = 0;

    for (0..dealer_hand.hand.num_cards) |x| {
        if (x == 1 and dealer_hand.hide_down_card) {
            continue;
        }

        tmp_v = dealer_hand.hand.cards[x].value + 1;
        v = if (tmp_v > 9) 10 else tmp_v;

        if (method == .Soft and v == 1 and total < 11) {
            v = 11;
        }

        total += v;
    }

    if (method == .Soft and total > 21) {
        return dealer_get_value(dealer_hand, .Hard);
    }

    return total;
}

fn draw_dealer_hand(game: *const Game) void {
    const dealer_hand = &game.dealer_hand;
    var card: *const Card = undefined;

    print(game, " ", .{});

    for (0..dealer_hand.hand.num_cards) |i| {
        if (i == 1 and dealer_hand.hide_down_card) {
            print(game, "{s} ", .{get_card_face(game, 13, 0)});
        } else {
            card = &dealer_hand.hand.cards[i];
            print(game, "{s} ", .{get_card_face(game, card.value, card.suit)});
        }
    }

    print(game, " ⇒  {d}\n", .{dealer_get_value(dealer_hand, .Soft)});
}

pub fn player_get_value(player_hand: *const PlayerHand, method: CountMethod) u32 {
    var total: u32 = 0;

    for (0..player_hand.hand.num_cards) |x| {
        const tmp_v: u32 = player_hand.hand.cards[x].value + 1;
        var v: u32 = if (tmp_v > 9) 10 else tmp_v;

        if (method == .Soft and v == 1 and total < 11) {
            v = 11;
        }

        total += v;
    }

    if (method == .Soft and total > 21) {
        return player_get_value(player_hand, .Hard);
    }

    return total;
}

pub fn player_is_busted(player_hand: *const PlayerHand) bool {
    return player_get_value(player_hand, .Soft) > 21;
}

fn player_draw_hand(game: *const Game, index: usize) void {
    const player_hand = &game.player_hands[index];

    print(game, " ", .{});

    for (0..player_hand.hand.num_cards) |i| {
        const card = &player_hand.hand.cards[i];
        print(game, "{s} ", .{get_card_face(game, card.value, card.suit)});
    }

    print(game, " ⇒  {d}  ", .{player_get_value(player_hand, .Soft)});

    switch (player_hand.status) {
        .Lost => print(game, "-", .{}),
        .Won => print(game, "+", .{}),
        else => {},
    }

    const bet: f64 = @as(f64, @floatFromInt(player_hand.bet));
    print(game, "${d:.2}", .{bet / 100.0});

    if (!player_hand.played and index == game.current_player_hand) {
        print(game, " ⇐", .{});
    }

    print(game, "  ", .{});

    switch (player_hand.status) {
        .Lost => print(game, "{s}", .{if (player_is_busted(player_hand)) "Busted!" else "Lose!"}),
        .Won => print(game, "{s}", .{if (is_blackjack(&player_hand.hand)) "Blackjack!" else "Won!"}),
        .Push => print(game, "Push", .{}),
        else => {},
    }

    print(game, "\n\n", .{});
}

fn clear(game: *const Game) void {
    print(game, "\x1b[2J\x1b[H", .{});
}

pub fn draw_hands(game: *const Game) void {
    clear(game);
    print(game, "\n Dealer: \n", .{});
    draw_dealer_hand(game);

    const money: f64 = @as(f64, @floatFromInt(game.money));
    print(game, "\n Player ${d:.2}:\n", .{money / 100.0});

    for (0..game.total_player_hands) |x| {
        player_draw_hand(game, x);
    }
}

pub fn player_can_hit(player_hand: *const PlayerHand) bool {
    return !player_hand.played and
        !player_hand.stood and
        player_get_value(player_hand, .Hard) != 21 and
        !is_blackjack(&player_hand.hand) and
        !player_is_busted(player_hand);
}

pub fn player_can_stand(player_hand: *const PlayerHand) bool {
    return !player_hand.stood and
        !player_is_busted(player_hand) and
        !is_blackjack(&player_hand.hand);
}

fn all_bets(game: *const Game) u32 {
    var bets: u32 = 0;

    for (game.player_hands[0..game.total_player_hands]) |player_hand| {
        bets += player_hand.bet;
    }

    return bets;
}

pub fn player_can_split(game: *const Game) bool {
    const player_hand = &game.player_hands[game.current_player_hand];

    if (player_hand.stood or game.total_player_hands >= MAX_PLAYER_HANDS) {
        return false;
    }

    if (game.money < all_bets(game) + player_hand.bet) {
        return false;
    }

    return player_hand.hand.num_cards == 2 and
        player_hand.hand.cards[0].value == player_hand.hand.cards[1].value;
}

pub fn player_can_dbl(game: *const Game) bool {
    const player_hand = &game.player_hands[game.current_player_hand];

    if (game.money < all_bets(game) + player_hand.bet) {
        return false;
    }

    if (player_hand.stood or
        player_hand.hand.num_cards != 2 or
        player_is_busted(player_hand) or
        is_blackjack(&player_hand.hand))
    {
        return false;
    }

    return true;
}

pub fn player_is_done(game: *Game, player_hand: *PlayerHand) bool {
    if (player_hand.played or
        player_hand.stood or
        is_blackjack(&player_hand.hand) or
        player_is_busted(player_hand) or
        player_get_value(player_hand, .Soft) == 21 or
        player_get_value(player_hand, .Hard) == 21)
    {
        player_hand.played = true;

        if (!player_hand.paid and player_is_busted(player_hand)) {
            player_hand.paid = true;
            player_hand.status = .Lost;
            game.money -= player_hand.bet;
        }

        return true;
    }

    return false;
}

fn more_hands_to_play(game: *const Game) bool {
    return game.current_player_hand < game.total_player_hands - 1;
}

fn play_more_hands(game: *Game) anyerror!void {
    game.current_player_hand += 1;
    var player_hand = &game.player_hands[game.current_player_hand];
    deal_card(&game.shoe, &player_hand.hand);

    if (player_is_done(game, player_hand)) {
        try process(game);
        return;
    }

    draw_hands(game);
    try player_get_action(game);
}

fn need_to_play_dealer_hand(game: *const Game) bool {
    for (game.player_hands[0..game.total_player_hands]) |player_hand| {
        if (!(player_is_busted(&player_hand) or
            is_blackjack(&player_hand.hand)))
        {
            return true;
        }
    }

    return false;
}

pub fn dealer_is_busted(dealer_hand: *const DealerHand) bool {
    return dealer_get_value(dealer_hand, .Soft) > 21;
}

pub fn normalize_bet(game: *Game) void {
    if (game.current_bet < MIN_BET) {
        game.current_bet = MIN_BET;
    } else if (game.current_bet > MAX_BET) {
        game.current_bet = MAX_BET;
    }

    if (game.current_bet > game.money) {
        game.current_bet = @truncate(game.money);
    }
}

pub fn save_game(game: *const Game) !void {
    const dir = std.Io.Dir.cwd();

    const file = try dir.createFile(game.io, SAVE_FILE, .{});
    defer file.close(game.io);

    var buffer: [128]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buffer, "{d}\n{d}\n{d}\n{d}\n{d}\n", .{
        game.num_decks,
        game.money,
        game.current_bet,
        game.deck_type,
        game.face_type,
    }) catch return error.BufferOverflow;

    try file.writeStreamingAll(game.io, formatted);
}

pub fn load_game(game: *Game) !void {
    const file = std.Io.Dir.cwd().openFile(game.io, SAVE_FILE, .{}) catch {
        return;
    };
    defer file.close(game.io);

    var file_buffer: [256]u8 = undefined;
    var bytes_read: usize = 0;
    while (bytes_read < file_buffer.len) {
        const n = file.readStreaming(game.io, &[_][]u8{file_buffer[bytes_read..]}) catch break;
        if (n == 0) break;
        bytes_read += n;
    }

    if (bytes_read == 0) return;

    var line_start: usize = 0;
    var line_num: usize = 0;
    var values: [5]u32 = undefined;

    for (0..bytes_read) |i| {
        if (file_buffer[i] == '\n' or i == bytes_read - 1) {
            const end = if (file_buffer[i] == '\n') i else i + 1;
            if (end > line_start) {
                values[line_num] = std.fmt.parseInt(u32, file_buffer[line_start..end], 10) catch 0;
                line_num += 1;
                if (line_num >= 5) break;
            }
            line_start = i + 1;
        }
    }

    if (line_num >= 5) {
        game.num_decks = @truncate(values[0]);
        game.money = values[1];
        game.current_bet = values[2];
        game.deck_type = @truncate(values[3]);
        game.face_type = @truncate(values[4]);
    }
}

pub fn pay_hands(game: *Game) !void {
    const dealer_hand = &game.dealer_hand;
    var player_hand: *PlayerHand = undefined;
    const dhv = dealer_get_value(dealer_hand, .Soft);
    const dhb = dealer_is_busted(dealer_hand);
    var phv: u32 = 0;

    for (0..game.total_player_hands) |x| {
        player_hand = &game.player_hands[x];
        if (player_hand.paid) continue;

        player_hand.paid = true;
        phv = player_get_value(player_hand, .Soft);

        if (dhb or phv > dhv) {
            if (is_blackjack(&player_hand.hand)) {
                var bet: f64 = @floatFromInt(player_hand.bet);
                bet *= 1.5;
                const new_bet: u32 = @intFromFloat(bet);
                player_hand.bet = new_bet;
            }

            game.money += player_hand.bet;
            player_hand.status = .Won;
        } else if (phv < dhv) {
            game.money -= player_hand.bet;
            player_hand.status = .Lost;
        } else {
            player_hand.status = .Push;
        }
    }

    normalize_bet(game);
    try save_game(game);
}

pub fn play_dealer_hand(game: *Game) !void {
    var dealer_hand = &game.dealer_hand;
    var soft_count: u32 = 0;
    var hard_count: u32 = 0;

    if (is_blackjack(&dealer_hand.hand)) {
        dealer_hand.hide_down_card = false;
    }

    if (!need_to_play_dealer_hand(game)) {
        try pay_hands(game);
        return;
    }

    dealer_hand.hide_down_card = false;

    soft_count = dealer_get_value(dealer_hand, .Soft);
    hard_count = dealer_get_value(dealer_hand, .Hard);

    while (soft_count < 18 and hard_count < 17) {
        deal_card(&game.shoe, &dealer_hand.hand);
        soft_count = dealer_get_value(dealer_hand, .Soft);
        hard_count = dealer_get_value(dealer_hand, .Hard);
    }

    try pay_hands(game);
}

pub fn read_line(game: *Game, buffer: []u8) ![]u8 {
    var idx: usize = 0;

    while (idx < buffer.len) {
        const byte = read_byte(game) orelse break;
        if (byte == '\n') break;
        buffer[idx] = byte;
        idx += 1;
    }

    return buffer[0..idx];
}

pub fn get_new_bet(game: *Game) !void {
    clear(game);
    draw_hands(game);

    print(game, " Current Bet: ${d}  Enter New Bet: $", .{game.current_bet / 100});

    var input: [32]u8 = undefined;
    const result = try read_line(game, &input);
    const tmp = std.fmt.parseInt(u32, result, 10) catch 0;

    game.current_bet = tmp * 100;
    normalize_bet(game);
    try save_game(game);
    try deal_new_hand(game);
}

pub fn get_new_num_decks(game: *Game) anyerror!void {
    clear(game);
    draw_hands(game);

    print(game, " Number Of Decks: {d}  Enter New Number Of Decks (1-8): ", .{game.num_decks});

    var input: [8]u8 = undefined;
    const result = try read_line(game, &input);
    var tmp = std.fmt.parseInt(u8, result, 10) catch 1;

    if (tmp < 1) tmp = 1;
    if (tmp > 8) tmp = 8;

    game.num_decks = tmp;
    try save_game(game);
    try game_options(game);
}

pub fn get_new_deck_type(game: *Game) !void {
    clear(game);
    draw_hands(game);
    print(game, " (1) Regular  (2) Aces  (3) Jacks  (4) Aces & Jacks  (5) Sevens  (6) Eights\n", .{});

    var input: [1]u8 = undefined;

    while (true) {
        input[0] = read_byte(game) orelse return;

        const tmp = std.fmt.parseInt(u8, input[0..1], 10) catch 0;
        game.deck_type = @as(u8, tmp);

        if (game.deck_type > 0 and game.deck_type < 7) {
            if (game.deck_type > 1) {
                game.num_decks = 8;
            }
            try build_new_shoe(game);
        } else {
            clear(game);
            draw_hands(game);
            try get_new_deck_type(game);
            return;
        }

        try save_game(game);
        draw_hands(game);
        try bet_options(game);
        break;
    }
}

pub fn get_new_face_type(game: *Game) !void {
    clear(game);
    draw_hands(game);
    print(game, " (1) A♠  (2) 🂡\n", .{});

    var input: [1]u8 = undefined;

    while (true) {
        input[0] = read_byte(game) orelse return;

        switch (input[0]) {
            '1' => game.face_type = 1,
            '2' => game.face_type = 2,
            else => {
                clear(game);
                draw_hands(game);
                try get_new_face_type(game);
                return;
            },
        }

        try save_game(game);
        draw_hands(game);
        try bet_options(game);
        break;
    }
}

pub fn game_options(game: *Game) !void {
    clear(game);
    draw_hands(game);
    print(game, " (N) Number of Decks  (T) Deck Type  (F) Face Type  (B) Back\n", .{});

    var input: [1]u8 = undefined;

    while (true) {
        input[0] = read_byte(game) orelse return;

        switch (input[0] | 0x20) {
            'n' => try get_new_num_decks(game),
            't' => try get_new_deck_type(game),
            'f' => try get_new_face_type(game),
            'b' => {
                clear(game);
                draw_hands(game);
                try bet_options(game);
                return;
            },
            else => {
                clear(game);
                draw_hands(game);
                try game_options(game);
                return;
            },
        }
        break;
    }
}

pub fn bet_options(game: *Game) anyerror!void {
    print(game, " (D) Deal Hand  (B) Change Bet  (O) Options  (Q) Quit\n", .{});

    var input: [1]u8 = undefined;

    while (true) {
        input[0] = read_byte(game) orelse return;

        switch (input[0] | 0x20) {
            'd' => {},
            'b' => try get_new_bet(game),
            'o' => try game_options(game),
            'q' => {
                game.quitting = true;
                clear(game);
            },
            else => {
                clear(game);
                draw_hands(game);
                try bet_options(game);
                return;
            },
        }
        break;
    }
}

pub fn process(game: *Game) !void {
    if (more_hands_to_play(game)) {
        try play_more_hands(game);
        return;
    }

    try play_dealer_hand(game);
    draw_hands(game);
    try bet_options(game);
}

pub fn player_hit(game: *Game) anyerror!void {
    var player_hand = &game.player_hands[game.current_player_hand];
    deal_card(&game.shoe, &player_hand.hand);

    if (player_is_done(game, player_hand)) {
        try process(game);
        return;
    }

    draw_hands(game);
    try player_get_action(game);
}

pub fn player_stand(game: *Game) !void {
    var player_hand = &game.player_hands[game.current_player_hand];

    player_hand.stood = true;
    player_hand.played = true;

    if (more_hands_to_play(game)) {
        try play_more_hands(game);
        return;
    }

    try play_dealer_hand(game);
    draw_hands(game);
    try bet_options(game);
}

pub fn player_split(game: *Game) !void {
    const new_hand = PlayerHand{
        .bet = game.current_bet,
        .hand = Hand{
            .cards = undefined,
            .num_cards = 0,
        },
        .played = false,
        .paid = false,
        .stood = false,
        .status = HandStatus.Unknown,
    };
    var hand_count = game.total_player_hands;
    var this_hand: *PlayerHand = undefined;
    var split_hand: *PlayerHand = undefined;
    var card: Card = undefined;

    if (!player_can_split(game)) {
        draw_hands(game);
        try player_get_action(game);
        return;
    }

    game.player_hands[game.total_player_hands] = new_hand;
    game.total_player_hands += 1;

    while (hand_count > game.current_player_hand) {
        game.player_hands[hand_count] = game.player_hands[hand_count - 1];
        hand_count -= 1;
    }

    this_hand = &game.player_hands[game.current_player_hand];
    split_hand = &game.player_hands[game.current_player_hand + 1];

    card = this_hand.hand.cards[1];
    split_hand.hand.cards[0] = card;
    split_hand.hand.num_cards = 1;
    this_hand.hand.num_cards = 1;

    deal_card(&game.shoe, &this_hand.hand);

    if (player_is_done(game, this_hand)) {
        try process(game);
        return;
    }

    draw_hands(game);
    try player_get_action(game);
}

pub fn player_dbl(game: *Game) !void {
    var player_hand = &game.player_hands[game.current_player_hand];

    deal_card(&game.shoe, &player_hand.hand);
    player_hand.played = true;
    player_hand.bet *= 2;

    if (player_is_done(game, player_hand)) {
        try process(game);
    }
}

pub fn player_get_action(game: *Game) anyerror!void {
    const player_hand = &game.player_hands[game.current_player_hand];
    print(game, " ", .{});

    if (player_can_hit(player_hand)) print(game, "(H) Hit  ", .{});
    if (player_can_stand(player_hand)) print(game, "(S) Stand  ", .{});
    if (player_can_split(game)) print(game, "(P) Split  ", .{});
    if (player_can_dbl(game)) print(game, "(D) Double  ", .{});

    print(game, "\n", .{});

    while (true) {
        const result = read_byte(game) orelse return;

        switch (result | 0x20) {
            'h' => try player_hit(game),
            's' => try player_stand(game),
            'p' => try player_split(game),
            'd' => try player_dbl(game),
            else => {
                clear(game);
                draw_hands(game);
                try player_get_action(game);
                return;
            },
        }

        break;
    }
}

pub fn insure_hand(game: *Game) !void {
    var player_hand = &game.player_hands[game.current_player_hand];

    player_hand.bet /= 2;
    player_hand.played = true;
    player_hand.paid = true;
    player_hand.status = .Lost;
    game.money -= player_hand.bet;

    draw_hands(game);
    try bet_options(game);
}

pub fn no_insurance(game: *Game) !void {
    var dealer_hand = &game.dealer_hand;
    var player_hand: *PlayerHand = undefined;

    if (is_blackjack(&dealer_hand.hand)) {
        dealer_hand.hide_down_card = false;
        try pay_hands(game);
        draw_hands(game);
        try bet_options(game);
        return;
    }

    player_hand = &game.player_hands[game.current_player_hand];

    if (player_is_done(game, player_hand)) {
        try play_dealer_hand(game);
        draw_hands(game);
        try bet_options(game);
        return;
    }

    draw_hands(game);
    try player_get_action(game);
}

pub fn ask_insurance(game: *Game) !void {
    print(game, " Insurance?  (Y) Yes  (N) No\n", .{});

    var input: [1]u8 = undefined;

    while (true) {
        input[0] = read_byte(game) orelse return;

        switch (input[0] | 0x20) {
            'y' => {
                try insure_hand(game);
                break;
            },
            'n' => {
                try no_insurance(game);
                break;
            },
            else => {
                clear(game);
                draw_hands(game);
                try ask_insurance(game);
                return;
            },
        }

        break;
    }
}

pub fn deal_new_hand(game: *Game) !void {
    const cards = [_]Card{Card{ .value = 0, .suit = 0 }} ** MAX_CARDS_PER_HAND;

    const hand = Hand{
        .cards = cards,
        .num_cards = 0,
    };

    var player_hand = PlayerHand{
        .hand = hand,
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

    if (dealer_upcard_is_ace(dealer_hand) and !is_blackjack(&player_hand.hand)) {
        draw_hands(game);
        try ask_insurance(game);
        return;
    }

    if (player_is_done(game, &player_hand)) {
        dealer_hand.hide_down_card = false;
        try pay_hands(game);
        draw_hands(game);
        try bet_options(game);
        return;
    }

    draw_hands(game);
    try player_get_action(game);
    try save_game(game);
}

pub fn buffer_on(tty: *const std.Io.File) !void {
    const term = std.posix.tcgetattr(tty.handle) catch return;
    try std.posix.tcsetattr(tty.handle, .NOW, term);
}

pub fn buffer_off(tty: *const std.Io.File) !void {
    var term = std.posix.tcgetattr(tty.handle) catch return;
    term.lflag.ICANON = false;
    try std.posix.tcsetattr(tty.handle, .NOW, term);
}
