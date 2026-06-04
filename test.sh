#!/bin/sh
set -e

zig build test --summary all

rm -rf zig-out/coverage
zig build
zig build coverage

# Drive the real binary so main.zig and the terminal setup are measured too.
# The eights deck (deck_type 6) makes every dealt card an eight, so a stand
# then quit is fully deterministic with no RNG dependence.
printf '8\n100000\n500\n6\n0\n' > bj.txt
printf 'sq' | kcov --include-pattern=src/ zig-out/coverage zig-out/bin/bj >/dev/null 2>&1 || true
rm -f bj.txt

report="$(pwd)/zig-out/coverage/kcov-merged/index.html"
percent=$(grep -ho '^ *"percent_covered": "[0-9.]*"' zig-out/coverage/kcov-merged/coverage.json 2>/dev/null | head -1 | grep -o '[0-9][0-9.]*' || true)

echo
echo "Coverage: ${percent}% (src/, merged unit + integration)"
printf 'Report: \033]8;;file://%s\033\\%s\033]8;;\033\\\n' "$report" "$report"
