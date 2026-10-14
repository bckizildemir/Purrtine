#!/usr/bin/env bash
# sim-memory.sh UDID - memory that one booted simulator uses on the Mac.
#
# Finds the device's launchd_sim (its argv holds the UDID), takes every descendant
# process, and prints the summed physical footprint (footprint(1)) and summed RSS.
# Footprint is the number to compare; RSS double-counts shared pages.

set -euo pipefail
udid="${1:?usage: sim-memory.sh UDID}"

pids="$(ps -axo pid=,ppid=,command= | /usr/bin/python3 -c '
import sys
udid = sys.argv[1]
rows = []
for line in sys.stdin:
    parts = line.split(None, 2)
    if len(parts) < 3:
        continue
    rows.append((int(parts[0]), int(parts[1]), parts[2]))
roots = [pid for pid, _, cmd in rows if cmd.startswith("launchd_sim") and udid in cmd]
if not roots:
    sys.exit(1)
children = {}
for pid, ppid, _ in rows:
    children.setdefault(ppid, []).append(pid)
seen, stack = [], list(roots)
while stack:
    pid = stack.pop()
    seen.append(pid)
    stack.extend(children.get(pid, []))
print(" ".join(map(str, seen)))' "$udid")" || { echo "sim-memory: no launchd_sim for $udid (not booted?)" >&2; exit 1; }

count=$(wc -w <<<"$pids" | tr -d ' ')
args=()
for pid in $pids; do args+=(-p "$pid"); done
footprint_bytes="$(footprint -f bytes --noCategories "${args[@]}" 2>/dev/null \
  | awk '/Footprint:/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) {v=$i; break}
         if ($1 == "Summary") {sum=v} else {one=v}}
         END {print (sum != "" ? sum : one) + 0}')"
rss_kb="$(ps -o rss= -p "$(tr ' ' ',' <<<"$pids")" | awk '{s+=$1} END {print s+0}')"
printf 'processes=%s footprint_mib=%d rss_mib=%d\n' "$count" $((footprint_bytes / 1048576)) $((rss_kb / 1024))
