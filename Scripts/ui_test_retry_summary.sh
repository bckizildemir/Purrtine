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
#
# Every test that passed only on retry also prints a GitHub annotation line
# (::warning title=UI test passed only on retry::Class.test), and the same list is appended to
# $GITHUB_STEP_SUMMARY when that variable is set (#152).

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

    report_recovered "$recovered"
}

# Makes every test that passed only on retry visible on the PR page (#152): one GitHub warning
# annotation per test, and the same list in the job summary when GITHUB_STEP_SUMMARY is set. The
# exit status is untouched: a warning does not turn the job red.
report_recovered() {
    local recovered="$1"
    local name display

    [[ -n "$recovered" ]] || return 0

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        # "Class test" (from -[Class test]) becomes "Class.test"; "%" is escaped for the annotation.
        display="${name// /.}"
        printf '::warning title=UI test passed only on retry::%s\n' "${display//%/%25}"
    done <<< "$recovered"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            printf '### UI tests that passed only on retry (%s)\n\n' "$(count_lines "$recovered")"
            while IFS= read -r name; do
                [[ -n "$name" ]] || continue
                printf -- '- `%s`\n' "${name// /.}"
            done <<< "$recovered"
            printf '\n'
        } >> "$GITHUB_STEP_SUMMARY"
    fi
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

assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local label="$3"

    if grep -Fq -- "$unexpected" <<< "$output"; then
        printf 'self-test failed: %s\nDid not expect to find: %s\nActual output:\n%s\n' \
            "$label" \
            "$unexpected" \
            "$output" >&2
        exit 1
    fi
}

assert_empty_file() {
    local file="$1"
    local label="$2"

    if [[ -s "$file" ]]; then
        printf 'self-test failed: %s\nFile content:\n%s\n' "$label" "$(cat "$file")" >&2
        exit 1
    fi
}

self_test_tmp=""

cleanup_self_test() {
    if [[ -n "$self_test_tmp" ]]; then
        rm -f "$self_test_tmp"/*.log "$self_test_tmp"/*.md
        rmdir "$self_test_tmp"
    fi
}

run_self_test() {
    local output

    self_test_tmp="$(mktemp -d)"
    trap cleanup_self_test EXIT
    # CI sets this for the whole job; the self-test must not write into the real job summary.
    unset GITHUB_STEP_SUMMARY

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
    assert_contains "$output" \
        "::warning title=UI test passed only on retry::PurrtineUITests.CriticalFlowsUITests.testRetried" \
        "pass-on-retry annotation"
    assert_not_contains "$output" "::warning title=UI test passed only on retry::PurrtineUITests.CriticalFlowsUITests.testGreen" \
        "pass-on-retry annotation skips a test that passed first time"

    # The same list goes to the job summary file when GITHUB_STEP_SUMMARY is set.
    local summary_file="$self_test_tmp/step-summary.md"
    : > "$summary_file"
    output="$(GITHUB_STEP_SUMMARY="$summary_file" print_summary "$self_test_tmp/pass-on-retry.log")"
    assert_contains "$(cat "$summary_file")" "### UI tests that passed only on retry (1)" "step summary heading"
    assert_contains "$(cat "$summary_file")" \
        '- `PurrtineUITests.CriticalFlowsUITests.testRetried`' \
        "step summary test name"

    output="$(print_summary "$self_test_tmp/still-failing.log")"
    assert_contains "$output" "passed on retry (0):" "still-failing recovered count"
    assert_not_contains "$output" "::warning" "still-failing has no annotation"
    : > "$summary_file"
    GITHUB_STEP_SUMMARY="$summary_file" print_summary "$self_test_tmp/still-failing.log" > /dev/null
    assert_empty_file "$summary_file" "still-failing writes no step summary"
    assert_contains "$output" "did not pass (1):" "still-failing did-not-pass count"
    assert_contains "$output" \
        "- PurrtineUITests.CriticalFlowsUITests testBroken" \
        "still-failing test name"

    output="$(print_summary "$self_test_tmp/green.log")"
    assert_contains "$output" "no test failed; no retry was needed" "green run"

    output="$(print_summary "$self_test_tmp/alternate-format.log")"
    assert_contains "$output" "passed on retry (1):" "alternate format recovered count"
    assert_contains "$output" "- CriticalFlowsUITests.testAlt()" "alternate format test name"
    assert_contains "$output" \
        "::warning title=UI test passed only on retry::CriticalFlowsUITests.testAlt()" \
        "alternate format annotation"

    output="$(print_summary "$self_test_tmp/green.log")"
    assert_not_contains "$output" "::warning" "green run has no annotation"

    printf 'ui_test_retry_summary self-test: PASS\n'
}

if [[ "${1:-}" == "--self-test" ]]; then
    run_self_test
    exit 0
fi

print_summary "${1:?Usage: ui_test_retry_summary.sh LOG | --self-test}"
