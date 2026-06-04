# blackjack-zig

Console Blackjack written in Zig.

[![CI](https://github.com/gdonald/blackjack-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/gdonald/blackjack-zig/actions/workflows/ci.yml)

![Blackjack](https://raw.githubusercontent.com/gdonald/blackjack-zig/master/ss2.png)

![Blackjack](https://raw.githubusercontent.com/gdonald/blackjack-zig/master/ss1.png)

## Requirements

Zig 0.16.0.

## Running

```sh
zig build run
```

To build the executable without running it:

```sh
zig build
```

The binary is written to `zig-out/bin/bj`.

## Testing

```sh
zig build test
```

`test.sh` runs the suite and produces a merged kcov coverage report
(unit tests plus an end-to-end run of the real binary):

```sh
./test.sh
```

The report is written to `zig-out/coverage/kcov-merged/index.html`.

## License

[![GitHub](https://img.shields.io/github/license/gdonald/blackjack-zig?color=aa0000)](https://github.com/gdonald/blackjack-zig/blob/master/LICENSE)

### Other Blackjack Implementations:

I've written Blackjack in [some other programming languages](https://github.com/gdonald?tab=repositories&q=blackjack&type=public&language=&sort=stargazers) too.  Check them out!
