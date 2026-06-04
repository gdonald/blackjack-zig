const std = @import("std");
const testing = std.testing;
const bj = @import("bj");

const Card = bj.Card;

const ACE: u8 = 0;
const FIVE: u8 = 4;
const SEVEN: u8 = 6;
const EIGHT: u8 = 7;
const NINE: u8 = 8;
const TEN: u8 = 9;
const KING: u8 = 12;

extern "c" fn openpty(
    amaster: *c_int,
    aslave: *c_int,
    name: ?[*]u8,
    termp: ?*const anyopaque,
    winp: ?*const anyopaque,
) c_int;

const Ctx = struct {
    threaded: std.Io.Threaded = std.Io.Threaded.init_single_threaded,
    out_buf: [1 << 16]u8 = undefined,
    writer: std.Io.Writer = undefined,
    reader: std.Io.Reader = undefined,
    game: bj.Game = undefined,

    fn wire(self: *Ctx, input: []const u8) void {
        self.writer = std.Io.Writer.fixed(&self.out_buf);
        self.reader = std.Io.Reader.fixed(input);
        self.game = bj.Game.init();
        self.game.prng = std.Random.DefaultPrng.init(42);
        self.game.io = self.threaded.io();
        self.game.in = &self.reader;
        self.game.out = &self.writer;
    }

    fn out(self: *Ctx) []const u8 {
        return self.writer.buffered();
    }
};

fn set_shoe(game: *bj.Game, values: []const u8) void {
    for (values, 0..) |value, i| {
        game.shoe.cards[i] = Card{ .value = value, .suit = 0 };
    }
    game.shoe.num_cards = @intCast(values.len);
    game.shoe.current_card = 0;
}

fn set_player(game: *bj.Game, values: []const u8) void {
    var player_hand = bj.PlayerHand.init();
    player_hand.status = .Unknown;
    for (values, 0..) |value, i| {
        player_hand.hand.cards[i] = Card{ .value = value, .suit = 0 };
    }
    player_hand.hand.num_cards = @intCast(values.len);
    player_hand.bet = 500;
    game.player_hands[0] = player_hand;
    game.total_player_hands = 1;
    game.current_player_hand = 0;
}

fn set_dealer(game: *bj.Game, values: []const u8, hide: bool) void {
    for (values, 0..) |value, i| {
        game.dealer_hand.hand.cards[i] = Card{ .value = value, .suit = 0 };
    }
    game.dealer_hand.hand.num_cards = @intCast(values.len);
    game.dealer_hand.hide_down_card = hide;
}

fn set_table(game: *bj.Game) void {
    set_dealer(game, &[_]u8{ EIGHT, EIGHT }, false);
    set_player(game, &[_]u8{ EIGHT, EIGHT });
}

fn write_save(game: *bj.Game, content: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(game.io, "bj.txt", .{});
    defer file.close(game.io);
    try file.writeStreamingAll(game.io, content);
}

fn remove_save(game: *bj.Game) void {
    std.Io.Dir.cwd().deleteFile(game.io, "bj.txt") catch {};
}

fn has(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "draw_hands renders the dealer and player tables" {
    var ctx: Ctx = .{};
    ctx.wire("");
    set_table(&ctx.game);

    bj.draw_hands(&ctx.game);

    const output = ctx.out();
    try testing.expect(has(output, "Dealer:"));
    try testing.expect(has(output, "Player"));
}

test "draw_hands shows the down card hidden and the busted label" {
    var ctx: Ctx = .{};
    ctx.wire("");
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ KING, KING, KING });
    ctx.game.player_hands[0].status = .Lost;

    bj.draw_hands(&ctx.game);

    const output = ctx.out();
    try testing.expect(has(output, "??"));
    try testing.expect(has(output, "Busted!"));
}

test "bet_options quits on q" {
    var ctx: Ctx = .{};
    ctx.wire("q");
    set_table(&ctx.game);

    try bj.bet_options(&ctx.game);
    try testing.expect(ctx.game.quitting);
}

test "bet_options rejects an unknown key then quits" {
    var ctx: Ctx = .{};
    ctx.wire("zq");
    set_table(&ctx.game);

    try bj.bet_options(&ctx.game);
    try testing.expect(ctx.game.quitting);
}

test "bet_options opens options and returns via back then quits" {
    var ctx: Ctx = .{};
    ctx.wire("obq");
    set_table(&ctx.game);

    try bj.bet_options(&ctx.game);
    try testing.expect(ctx.game.quitting);
}

test "get_new_face_type sets the unicode faces then quits" {
    var ctx: Ctx = .{};
    ctx.wire("2q");
    set_table(&ctx.game);

    try bj.get_new_face_type(&ctx.game);
    try testing.expectEqual(@as(u8, 2), ctx.game.face_type);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "get_new_face_type rejects a bad key then accepts a valid one" {
    var ctx: Ctx = .{};
    ctx.wire("x1q");
    set_table(&ctx.game);

    try bj.get_new_face_type(&ctx.game);
    try testing.expectEqual(@as(u8, 1), ctx.game.face_type);
    remove_save(&ctx.game);
}

test "get_new_deck_type selects the eights deck then quits" {
    var ctx: Ctx = .{};
    ctx.wire("6q");
    set_table(&ctx.game);

    try bj.get_new_deck_type(&ctx.game);
    try testing.expectEqual(@as(u8, 6), ctx.game.deck_type);
    try testing.expectEqual(@as(u8, 8), ctx.game.num_decks);
    remove_save(&ctx.game);
}

test "get_new_deck_type rejects an out of range key then accepts a valid one" {
    var ctx: Ctx = .{};
    ctx.wire("96q");
    set_table(&ctx.game);

    try bj.get_new_deck_type(&ctx.game);
    try testing.expectEqual(@as(u8, 6), ctx.game.deck_type);
    remove_save(&ctx.game);
}

test "game_options changes the deck count via a typed line then backs out" {
    var ctx: Ctx = .{};
    ctx.wire("n3\nbq");
    set_table(&ctx.game);

    try bj.game_options(&ctx.game);
    try testing.expectEqual(@as(u8, 3), ctx.game.num_decks);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "game_options rejects an unknown key then backs out" {
    var ctx: Ctx = .{};
    ctx.wire("xbq");
    set_table(&ctx.game);

    try bj.game_options(&ctx.game);
    try testing.expect(ctx.game.quitting);
}

test "get_new_bet reads a typed amount then deals and stands to quit" {
    var ctx: Ctx = .{};
    ctx.wire("1000\nsq");
    ctx.game.money = 1000000;
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.get_new_bet(&ctx.game);
    try testing.expectEqual(@as(u32, 100000), ctx.game.current_bet);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "get_new_bet clamps a non numeric amount to the minimum" {
    var ctx: Ctx = .{};
    ctx.wire("abc\nsq");
    ctx.game.money = 1000000;
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.get_new_bet(&ctx.game);
    try testing.expectEqual(bj.MIN_BET, ctx.game.current_bet);
    remove_save(&ctx.game);
}

test "player_get_action stands and pays out the hand" {
    var ctx: Ctx = .{};
    ctx.wire("sq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.player_get_action(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "player_get_action hits into a bust" {
    var ctx: Ctx = .{};
    ctx.wire("hq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.player_get_action(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Lost, ctx.game.player_hands[0].status);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "player_get_action doubles down into a bust" {
    var ctx: Ctx = .{};
    ctx.wire("dq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.player_get_action(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "player_get_action rejects an unknown key then stands" {
    var ctx: Ctx = .{};
    ctx.wire("zsq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_table(&ctx.game);

    try bj.player_get_action(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "player_split refuses a non pair and asks for an action" {
    var ctx: Ctx = .{};
    ctx.wire("sq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_player(&ctx.game, &[_]u8{ EIGHT, SEVEN });
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, false);

    try bj.player_split(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "ask_insurance takes the insurance bet" {
    var ctx: Ctx = .{};
    ctx.wire("yq");
    ctx.game.money = 10000;
    set_dealer(&ctx.game, &[_]u8{ ACE, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });
    ctx.game.player_hands[0].bet = 500;

    try bj.ask_insurance(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Lost, ctx.game.player_hands[0].status);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "ask_insurance declines then plays the hand out" {
    var ctx: Ctx = .{};
    ctx.wire("nsq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_dealer(&ctx.game, &[_]u8{ ACE, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });

    try bj.ask_insurance(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "ask_insurance rejects an unknown key then declines" {
    var ctx: Ctx = .{};
    ctx.wire("xnsq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_dealer(&ctx.game, &[_]u8{ ACE, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });

    try bj.ask_insurance(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "declining insurance against a dealer blackjack loses the hand" {
    var ctx: Ctx = .{};
    ctx.wire("q");
    ctx.game.money = 10000;
    set_dealer(&ctx.game, &[_]u8{ ACE, KING }, true);
    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });
    ctx.game.player_hands[0].bet = 500;

    try bj.no_insurance(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Lost, ctx.game.player_hands[0].status);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "pay_hands pays a blackjack at three to two" {
    var ctx: Ctx = .{};
    ctx.wire("");
    ctx.game.money = 10000;
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, false);
    set_player(&ctx.game, &[_]u8{ ACE, KING });
    ctx.game.player_hands[0].bet = 500;

    try bj.pay_hands(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Won, ctx.game.player_hands[0].status);
    try testing.expectEqual(@as(u128, 10750), ctx.game.money);
    remove_save(&ctx.game);
}

test "pay_hands pushes an equal hand" {
    var ctx: Ctx = .{};
    ctx.wire("");
    ctx.game.money = 10000;
    set_dealer(&ctx.game, &[_]u8{ KING, NINE }, false);
    set_player(&ctx.game, &[_]u8{ KING, NINE });
    ctx.game.player_hands[0].bet = 500;

    try bj.pay_hands(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Push, ctx.game.player_hands[0].status);
    try testing.expectEqual(@as(u128, 10000), ctx.game.money);
    remove_save(&ctx.game);
}

test "read input that ends mid prompt flags end of input" {
    var ctx: Ctx = .{};
    ctx.wire("");
    set_table(&ctx.game);

    try bj.bet_options(&ctx.game);
    try testing.expect(ctx.game.eof);
    try testing.expect(!ctx.game.quitting);
}

test "draw_hands shows the push label" {
    var ctx: Ctx = .{};
    ctx.wire("");
    set_table(&ctx.game);
    ctx.game.player_hands[0].status = .Push;

    bj.draw_hands(&ctx.game);
    try testing.expect(has(ctx.out(), "Push"));
}

test "player_get_action hits without busting then stands" {
    var ctx: Ctx = .{};
    ctx.wire("hsq");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{FIVE} ** 20));
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, false);
    set_player(&ctx.game, &[_]u8{ FIVE, FIVE });

    try bj.player_get_action(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "standing on a split hand advances to a hand that completes on the deal" {
    var ctx: Ctx = .{};
    ctx.wire("q");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{ ACE, EIGHT, EIGHT, EIGHT, EIGHT, EIGHT }));
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, true);

    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });
    var second = bj.PlayerHand.init();
    second.status = .Unknown;
    second.hand.cards[0] = Card{ .value = TEN, .suit = 0 };
    second.hand.num_cards = 1;
    second.bet = 500;
    ctx.game.player_hands[1] = second;
    ctx.game.total_player_hands = 2;
    ctx.game.current_player_hand = 0;

    try bj.player_stand(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "splitting tens into a made twenty one plays both hands" {
    var ctx: Ctx = .{};
    ctx.wire("sq");
    ctx.game.money = 10000;
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{ ACE, EIGHT, EIGHT, EIGHT, EIGHT, EIGHT }));
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ TEN, TEN });
    ctx.game.player_hands[0].bet = 500;

    try bj.player_split(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "declining insurance on an already finished hand plays the dealer" {
    var ctx: Ctx = .{};
    ctx.wire("q");
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &([_]u8{EIGHT} ** 20));
    set_dealer(&ctx.game, &[_]u8{ EIGHT, EIGHT }, true);
    set_player(&ctx.game, &[_]u8{ EIGHT, EIGHT });
    ctx.game.player_hands[0].played = true;

    try bj.no_insurance(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "a dealt blackjack pays immediately without an action prompt" {
    var ctx: Ctx = .{};
    ctx.wire("q");
    ctx.game.money = 10000;
    ctx.game.num_decks = 8;
    set_shoe(&ctx.game, &[_]u8{ ACE, EIGHT, KING, EIGHT });

    try bj.deal_new_hand(&ctx.game);
    try testing.expectEqual(bj.HandStatus.Won, ctx.game.player_hands[0].status);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "buffer_off and buffer_on toggle a real terminal" {
    var master: c_int = undefined;
    var slave: c_int = undefined;
    if (openpty(&master, &slave, null, null, null) != 0) return error.SkipZigTest;
    defer _ = std.c.close(master);
    defer _ = std.c.close(slave);

    const tty = std.Io.File{ .handle = slave, .flags = .{ .nonblocking = false } };
    try bj.buffer_off(&tty);
    try bj.buffer_on(&tty);
}

test "run_game plays a full eights session through every menu then quits" {
    var ctx: Ctx = .{};
    ctx.wire("phdot6ot96of2ofz1on3\nboxbb1000\nszq");
    try write_save(&ctx.game, "8\n100000\n500\n6\n0\n");

    try bj.run_game(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}

test "run_game plays an aces session covering insurance then quits" {
    var ctx: Ctx = .{};
    ctx.wire("ydnsdxnsq");
    try write_save(&ctx.game, "8\n100000\n500\n2\n0\n");

    try bj.run_game(&ctx.game);
    try testing.expect(ctx.game.quitting);
    remove_save(&ctx.game);
}
