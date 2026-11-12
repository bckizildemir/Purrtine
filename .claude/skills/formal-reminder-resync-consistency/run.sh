#!/bin/zsh
# One command: check the reminder-resync model with TLC, every rule on every config, and say
# whether the result is the known one. Run from anywhere:
#   .claude/skills/formal-reminder-resync-consistency/run.sh
#
# Needs Java 11+ and tla2tools.jar 1.7.4 (TLC 2.19). Set TLA2TOOLS to the jar, or let the script
# find the one mise installed (`mise install http:tla2tools@1.7.4` style installs land under
# ~/.local/share/mise/installs/). JAVA may name a java binary.
#
# Exit 0: every rule holds except the known findings, which still break.
# Exit 1: a rule breaks that is not a known finding, or a known finding stopped breaking
#         (then the code or the model changed: see SKILL.md, "Read a result").
# Exit 2: tool or model error.
set -u
here=${0:A:h}
repo=${here:h:h:h}

# Known findings: config:rule pairs that break at the sync commit. See SKILL.md "Findings".
known=(
  snooze:NoSnoozeAfterCompletion
  snooze:NoSnoozeForDeletedTask
  snooze:OffMeansSilent
  snooze:SnoozesWithinSlots
  snooze:WithinIOSCap
)

# The coverage record: the sync commit and the files the model describes.
sync=$(sed -n 's/^Sync commit: `\([0-9a-f]*\)`.*/\1/p' "$here/SKILL.md")
covered=(
  Purrtine/Utilities/NotificationResyncCoordinator.swift
  Purrtine/Utilities/NotificationManager.swift
  Purrtine/Utilities/CareTaskReminderSelection.swift
  Purrtine/Utilities/CareTaskWriter.swift
  Purrtine/Utilities/NotificationActionCoordinator.swift
  Purrtine/Utilities/CatDeletionService.swift
  Purrtine/Utilities/StagedDeleteWatch.swift
  Purrtine/PurrtineApp.swift
)
if [[ -n $sync ]] && git -C "$repo" cat-file -e "$sync^{commit}" 2>/dev/null; then
  changed=$(git -C "$repo" diff --stat "$sync" -- "${covered[@]}" | sed '$d')
  if [[ -n $changed ]]; then
    print -r -- "COVERED CODE CHANGED since sync commit $sync (committed or not):"
    print -r -- "$changed"
    print -r -- "Re-read the changed functions against the model before you trust this result."
    print
  fi
else
  print -r -- "WARNING: sync commit '$sync' not found in this checkout; cannot tell whether the code moved."
fi

jar=${TLA2TOOLS:-}
if [[ -z $jar ]]; then
  jar=$(ls -1 ~/.local/share/mise/installs/http-tla2tools/1.7.4/tla2tools.jar 2>/dev/null | head -1)
fi
[[ -f $jar ]] || { print -u2 "tla2tools.jar 1.7.4 not found: set TLA2TOOLS"; exit 2; }
java=${JAVA:-}
if [[ -z $java ]]; then
  java=$(ls -1d ~/.local/share/mise/installs/java/*/bin/java 2>/dev/null | head -1)
  [[ -z $java ]] && java=$(command -v java)
fi
[[ -x $java ]] || { print -u2 "java not found: set JAVA"; exit 2; }

work=$(mktemp -d /tmp/formal-reminder-resync.XXXXXX)
cp "$here/ReminderResync.tla" "$work/"
result=0
# One TLC run per rule: with several invariants TLC names only the first one a state breaks, so a
# rule could hide behind another. A breaking rule stops at its first counterexample, which is fast.
for cfg in resync snooze; do
  cfgfile="$here/ReminderResync-$cfg.cfg"
  rules=($(sed -n '/^INVARIANTS/,/^$/p' "$cfgfile" | sed 's/^INVARIANTS//; s/\\\*.*//'))
  print -r -- "== $cfg"
  for rule in $rules; do
    rcfg="$work/$cfg-$rule.cfg"
    sed '/^INVARIANTS/,$d' "$cfgfile" > "$rcfg"
    print -r -- "INVARIANT $rule" >> "$rcfg"
    out="$work/tlc-$cfg-$rule.out"
    ( cd "$work" && "$java" -XX:+UseParallelGC -Xmx3g -cp "$jar" tlc2.TLC -workers auto \
        -metadir "$work/states-$cfg-$rule" -config "$rcfg" ReminderResync.tla ) > "$out" 2>&1
    rm -rf "$work/states-$cfg-$rule"
    if grep -q -E "Parsing or semantic analysis failed|Error: TLC threw|Error: Evaluating" "$out"; then
      print -u2 "TLC error on $cfg/$rule; see $out"; exit 2
    fi
    states=$(grep -o '[0-9,]* distinct states found' "$out" | tail -1)
    if grep -q "Error: Invariant $rule is violated" "$out"; then
      if (( ${known[(Ie)$cfg:$rule]} )); then print -r -- "   breaks  $rule (known finding)"
      else print -r -- "   BREAKS  $rule (NEW)"; result=1; fi
    elif grep -q "No error has been found" "$out"; then
      if (( ${known[(Ie)$cfg:$rule]} )); then
        print -r -- "   HOLDS   $rule over $states (was a known finding: fixed, or the model drifted)"; result=1
      else print -r -- "   holds   $rule over $states"; fi
    else
      print -u2 "TLC did not finish $cfg/$rule; see $out"; exit 2
    fi
  done
done
print
print -r -- "TLC output: $work"
print -r -- "Read every break with /statechart on the same spec and config to get its shortest path."
exit $result
