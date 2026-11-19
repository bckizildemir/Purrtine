#!/bin/bash
#
# Splits the UI tests into shards so CI can run them on several runners at once.
#
# It reads every `func test...` in PurrtineUITests/*.swift, sorts the tests by name and gives test i
# (counting from 0) to shard (i mod COUNT) + 1. It prints one xcodebuild flag per line:
#   -only-testing:PurrtineUITests/<Class>/<test>
# Sorting by name spreads the slow tests well: on the 2026-11-18 run (50 tests, 1549 s) three shards
# came to 538, 514 and 497 s. A new test joins a shard by its name; no list to keep up to date.
#
# Usage:
#   Scripts/ui-test-shard.sh <shard> <count>    e.g. Scripts/ui-test-shard.sh 2 3
#   Scripts/ui-test-shard.sh --list             every test, one per line
#   Scripts/ui-test-shard.sh --self-test        every test is in exactly one shard, no shard is empty
#
# Bash 3.2 compatible (macOS /bin/bash): no mapfile, no associative arrays.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$ROOT/PurrtineUITests"
TARGET="PurrtineUITests"

# Prints "Class/test" for every test method, sorted. A test belongs to the last `class` declared above
# it in the same file. `private` and `static` functions are helpers, not tests.
list_tests() {
    local found=0 file
    for file in "$TEST_DIR"/*.swift; do
        [ -e "$file" ] || continue
        found=1
        awk '
            /^[[:space:]]*(final[[:space:]]+)?(@MainActor[[:space:]]+)?(final[[:space:]]+)?class[[:space:]]+[A-Za-z0-9_]+/ {
                line = $0
                sub(/.*class[[:space:]]+/, "", line)
                sub(/[^A-Za-z0-9_].*/, "", line)
                cls = line
            }
            /^[[:space:]]*(@MainActor[[:space:]]+)?func[[:space:]]+test[A-Za-z0-9_]*[[:space:]]*\(/ {
                if (cls == "") next
                line = $0
                sub(/.*func[[:space:]]+/, "", line)
                sub(/[^A-Za-z0-9_].*/, "", line)
                print cls "/" line
            }
        ' "$file"
    done
    if [ "$found" -eq 0 ]; then
        echo "No Swift files in $TEST_DIR" >&2
        return 1
    fi
}

print_shard() {
    local shard="$1" count="$2"
    list_tests | LC_ALL=C sort | awk -v s="$shard" -v n="$count" -v t="$TARGET" \
        '((NR - 1) % n) + 1 == s { print "-only-testing:" t "/" $0 }'
}

self_test() {
    local all total count shard joined
    all="$(list_tests | LC_ALL=C sort)"
    total="$(printf '%s\n' "$all" | grep -c . || true)"
    if [ "$total" -eq 0 ]; then
        echo "self-test FAILED: no UI tests found in $TEST_DIR" >&2
        return 1
    fi
    if [ "$(printf '%s\n' "$all" | uniq -d | grep -c . || true)" -ne 0 ]; then
        echo "self-test FAILED: a test name appears twice" >&2
        return 1
    fi
    for count in 1 2 3 4; do
        joined=""
        for shard in $(seq 1 "$count"); do
            out="$(print_shard "$shard" "$count")"
            if [ -z "$out" ]; then
                echo "self-test FAILED: shard $shard of $count is empty" >&2
                return 1
            fi
            joined="$joined$out"$'\n'
        done
        if [ "$(printf '%s' "$joined" | sed "s|^-only-testing:$TARGET/||" | LC_ALL=C sort)" != "$all" ]; then
            echo "self-test FAILED: the $count shards do not add up to the $total tests" >&2
            return 1
        fi
    done
    echo "self-test passed: $total UI tests, each in exactly one shard for 1-4 shards"
}

case "${1:-}" in
    --list) list_tests | LC_ALL=C sort ;;
    --self-test) self_test ;;
    *)
        if [ "$#" -ne 2 ] || ! [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt "$2" ]; then
            echo "usage: $0 <shard> <count> | --list | --self-test" >&2
            exit 2
        fi
        print_shard "$1" "$2"
        ;;
esac
