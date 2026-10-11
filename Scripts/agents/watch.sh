#!/bin/zsh
# Usage: Scripts/agents/watch.sh id1 id2 ...
# Exits when any listed background session (an id from `claude agents --json`) is no longer
# "working". Run it in the background; it polls once a minute.
ids=("$@")
while true; do
  out=$(claude agents --json 2>/dev/null | python3 -I -c '
import json,sys
ids=sys.argv[1:]
for a in json.load(sys.stdin):
    if a.get("id") in ids and a.get("state")!="working":
        print(a["id"], a.get("name"), a.get("status"), a.get("state"))
' "${ids[@]}")
  if [[ -n "$out" ]]; then echo "$out"; exit 0; fi
  sleep 60
done
