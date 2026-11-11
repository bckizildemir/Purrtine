#!/bin/bash
#
# Summarizes the -retry-tests-on-failure outcome of an xcodebuild UI-test log (#97).
#
# xcodebuild prints one "Test Case '...' started (Iteration N of M)." line per attempt and one
# "Test Case '...' passed|failed (...)." line per attempt. A test that failed an early iteration
# and passed a later one therefore has both a failed and a passed line. This script pairs the
# lines by test name, so a pass-on-retry is visible in the CI log and a test that failed
# without recovering is not mistaken for one that did.
#
# Usage:
#   Scripts/ui_test_retry_summary.sh ui-test.log
#   Scripts/ui_test_retry_summary.sh --self-test
#
# The exit status is 0 whenever the log was read: the xcodebuild exit status is the CI gate,
# not this report.

set -euo pipefail

# Prints "name<TAB>passed" or "name<TAB>failed" for every result line in the log.
# \047 is an apostrophe; it keeps the awk program free of shell-hostile quotes.
parse_results() {
    awk '
        {
            line = $0
            if (tolower(line) !~ /^test case /) next
            name = line
            sub(/^[^\047]*\047/, "", name)
            sub(/\047.*$/, "", name)
            gsub(/^-\[/, "", name)
            sub(/\]$/, "", name)
            if (name == "") next
            if (line ~ /\047[[:space:]]+passed[[:space:](]/) {
                print name "\tpassed"
            } else if (line ~ /\047[[:space:]]+failed[[:space:](]/) {
                print name "\tfailed"
            }
        }
    ' "$1"
}

count_lines() {
    printf '%s\n' "$1" | awk 'NF { count++ } END { print count + 0 }'
}

print_list() {
    printf '%s\n' "$1" | awk 'NF { print "    - " $0 }'
}

print_summary() {
    local log="$1"
    local results failed passed recovered did_not_pass

    results="$(parse_results "$log")"
    failed="$(printf '%s\n' "$results" | awk -F '\t' '$2 == "failed" { print $1 }' | sort -u)"
    passed="$(printf '%s\n' "$results" | awk -F '\t' '$2 == "passed" { print $1 }' | sort -u)"

    if [[ -z "$failed" ]]; then
        printf 'UI test retry summary: no test failed; no retry was needed.\n'
        return 0
    fi

    recovered="$(comm -12 <(printf '%s\n' "$failed") <(printf '%s\n' "$passed"))"
    did_not_pass="$(comm -23 <(printf '%s\n' "$failed") <(printf '%s\n' "$passed"))"

    printf 'UI test retry summary (xcodebuild -retry-tests-on-failure, -test-iterations 2):\n'
    printf '  passed on retry (%s):\n' "$(count_lines "$recovered")"
    print_list "$recovered"
    printf '  did not pass (%s):\n' "$(count_lines "$did_not_pass")"
    print_list "$did_not_pass"
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local label="$3"

    if ! grep -Fq -- "$expected" <<< "$output"; then
        printf 'self-test failed: %s\nExpected to find: %s\nActual output:\n%s\n' \
            "$label" \
            "$expected" \
            "$output" >&2
        exit 1
    fi
}

self_test_tmp=""

cleanup_self_test() {
    if [[ -n "$self_test_tmp" ]]; then
        rm -f "$self_test_tmp"/*.log
        rmdir "$self_test_tmp"
    fi
}

run_self_test() {
    local output

    self_test_tmp="$(mktemp -d)"
    trap cleanup_self_test EXIT

    cat > "$self_test_tmp/pass-on-retry.log" <<'LOG'
Test Case '-[PurrtineUITests.CriticalFlowsUITests testRetried]' started (Iteration 1 of 2).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testRetried]' failed (1.234 seconds).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testGreen]' started (Iteration 1 of 2).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testGreen]' passed (1.234 seconds).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testRetried]' started (Iteration 2 of 2).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testRetried]' passed (1.234 seconds).
LOG

    cat > "$self_test_tmp/still-failing.log" <<'LOG'
Test Case '-[PurrtineUITests.CriticalFlowsUITests testBroken]' started (Iteration 1 of 2).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testBroken]' failed (1.234 seconds).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testBroken]' started (Iteration 2 of 2).
Test Case '-[PurrtineUITests.CriticalFlowsUITests testBroken]' failed (1.234 seconds).
LOG

    cat > "$self_test_tmp/green.log" <<'LOG'
Test Case '-[PurrtineUITests.CriticalFlowsUITests testGreen]' passed (1.234 seconds).
LOG

    # Newer xcodebuild versions print "Test case 'Class.test()' passed on 'device'" instead.
    cat > "$self_test_tmp/alternate-format.log" <<'LOG'
Test case 'CriticalFlowsUITests.testAlt()' failed on 'iPhone 17 Pro' (1.234 seconds)
Test case 'CriticalFlowsUITests.testAlt()' passed on 'iPhone 17 Pro' (1.234 seconds)
LOG

    output="$(print_summary "$self_test_tmp/pass-on-retry.log")"
    assert_contains "$output" "passed on retry (1):" "pass-on-retry count"
    assert_contains "$output" \
        "- PurrtineUITests.CriticalFlowsUITests testRetried" \
        "pass-on-retry test name"
    assert_contains "$output" "did not pass (0):" "pass-on-retry did-not-pass count"

    output="$(print_summary "$self_test_tmp/still-failing.log")"
    assert_contains "$output" "passed on retry (0):" "still-failing recovered count"
    assert_contains "$output" "did not pass (1):" "still-failing did-not-pass count"
    assert_contains "$output" \
        "- PurrtineUITests.CriticalFlowsUITests testBroken" \
        "still-failing test name"

    output="$(print_summary "$self_test_tmp/green.log")"
    assert_contains "$output" "no test failed; no retry was needed" "green run"

    output="$(print_summary "$self_test_tmp/alternate-format.log")"
    assert_contains "$output" "passed on retry (1):" "alternate format recovered count"
    assert_contains "$output" "- CriticalFlowsUITests.testAlt()" "alternate format test name"

    printf 'ui_test_retry_summary self-test: PASS\n'
}

if [[ "${1:-}" == "--self-test" ]]; then
    run_self_test
    exit 0
fi

print_summary "${1:?Usage: ui_test_retry_summary.sh LOG | --self-test}"
