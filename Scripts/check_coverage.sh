#!/bin/bash

set -euo pipefail

result_bundle_path="${1:?Usage: check_coverage.sh RESULT_BUNDLE [MINIMUM_PERCENT]}"
minimum_coverage="${2:-17.5}"
target_name="CatCareCalendar.app"

coverage_report="$(xcrun xccov view --report --only-targets "${result_bundle_path}")"
printf '%s\n' "${coverage_report}"

actual_coverage="$(
    awk -v target="${target_name}" '
        $2 == target {
            value = $4
            sub(/%$/, "", value)
            print value
        }
    ' <<< "${coverage_report}"
)"

if [[ -z "${actual_coverage}" ]]; then
    printf 'error: Coverage for %s was not found.\n' "${target_name}" >&2
    exit 1
fi

if ! awk -v actual="${actual_coverage}" -v minimum="${minimum_coverage}" \
    'BEGIN { exit(actual + 0 >= minimum + 0 ? 0 : 1) }'; then
    printf 'error: App line coverage %s%% is below the required %s%%.\n' \
        "${actual_coverage}" \
        "${minimum_coverage}" >&2
    exit 1
fi

printf 'App line coverage %s%% meets the required %s%%.\n' \
    "${actual_coverage}" \
    "${minimum_coverage}"
