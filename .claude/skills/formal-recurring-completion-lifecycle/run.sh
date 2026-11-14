#!/bin/sh
# Checks the recurring-completion model. One command, from anywhere:
#   .claude/skills/formal-recurring-completion-lifecycle/run.sh
# Exit 0: the code still matches the model, the gate rules hold, and each known finding
#         still reproduces.
# Exit 1: a gate rule breaks (a regression) - its TLC trace is printed.
# Exit 2: a known finding no longer reproduces (fixed?) - update SKILL.md.
# Exit 3: the code moved away from the model (an anchor line is gone) - re-read the code.
# Exit 4: TLC or Java is missing.
# Env: TLA2TOOLS (path to tla2tools.jar), JAVA (java binary), KEEP=1 keeps the work folder.
set -u

SKILL_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SKILL_DIR/../../.." && pwd)
SPEC=RecurringCompletion
TLC_VERSION=1.7.4
TLC_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
KNOWN_FINDINGS=""   # the four findings were fixed in #141 and joined the gate

# --- 1. Is the code still the code the model describes? ------------------------------
# Each line is: <file>|<exact text the model relies on>. See SKILL.md "Coverage".
anchors_ok=1
while IFS='|' read -r file text; do
  [ -z "$file" ] && continue
  if ! grep -qF -- "$text" "$REPO/$file" 2>/dev/null; then
    echo "ANCHOR GONE: $file no longer contains: $text"
    anchors_ok=0
  fi
done <<'EOF'
Purrtine/Utilities/TaskActionService.swift|let effectiveCompletedForDate = completionDate(for: task, explicit: input.completedForDate)
Purrtine/Utilities/TaskActionService.swift|if let activeSchedule, activeSchedule.frequency != .once {
Purrtine/Utilities/TaskActionService.swift|if let scheduledDate = task.activeSchedule?.scheduledDate {
Purrtine/Utilities/TaskActionService.swift|.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: completedOccurrenceDate))
Purrtine/Utilities/TaskActionService.swift|.flatMap { activeSchedule.nextOccurrence(from: $0, calendar: calendar) }
Purrtine/Utilities/TaskActionService.swift|        activeSchedule.isActive = false
Purrtine/Utilities/TaskActionService.swift|            nextSchedule.task = task
Purrtine/Models/CareTask.swift|activeSchedules.min { first, second in
Purrtine/Models/CareTask.swift|        guard isActive else { return nil }
Purrtine/Models/CareTask.swift|guard endDate.map({ nextDate <= $0 }) ?? true else { return nil }
Purrtine/Utilities/CareTaskWriter.swift|let undo = CompletionUndo(capturing: task)
Purrtine/Utilities/CareTaskWriter.swift|undo.restore(in: context)
Purrtine/Utilities/CareTaskWriter.swift|task.completions.removeAll { completionIds.contains($0.id) == false }
Purrtine/Utilities/CareTaskWriter.swift|task.schedules.removeAll { scheduleIds.contains($0.id) == false }
Purrtine/Utilities/CareTaskWriter.swift|activeSchedule?.isActive = wasActiveScheduleActive
Purrtine/Utilities/CareTaskWriter.swift|await scheduler.removeDeliveredCareTaskNotifications(forTaskId: taskId)
Purrtine/Utilities/NotificationActionCoordinator.swift|let input = CareTaskCompletionInput(expectedOccurrence: occurrence)
Purrtine/Utilities/NotificationManager.swift|content.userInfo[Self.occurrenceDateKey] = occurrenceDate.timeIntervalSince1970
Purrtine/Utilities/NotificationManager.swift|let occurrence = (userInfo[Self.occurrenceDateKey] as? Double).map(Date.init(timeIntervalSince1970:))
Purrtine/Utilities/TaskActionService.swift|try validateOccurrence(of: task, for: input)
Purrtine/Utilities/TaskActionService.swift|guard openDay == calendar.startOfDay(for: expected) else {
Purrtine/Utilities/TaskActionService.swift|if let openDay, day > openDay {
Purrtine/Utilities/TaskActionService.swift|if TaskCalendarDerivation.hasCompletion(for: task, on: day, calendar: calendar) {
Purrtine/Models/TaskManagementViewModel.swift|expectedOccurrence = TaskActionService.openOccurrence(of: task)
Purrtine/Models/TaskManagementViewModel.swift|expectedOccurrence: TaskActionService.openOccurrence(of: task)
Purrtine/Models/TaskAssistantViewModel.swift|expectedOccurrence: pendingConfirmation.openOccurrence
Purrtine/Models/TaskFormPersistence.swift|let isDateUnchanged = openedScheduledDate == draft.scheduledDate
Purrtine/Models/TaskFormPersistence.swift|if writesScheduledDate {
Purrtine/Views/Tasks/TaskCalendarView.swift|guard hasCompletionForDate(task, date: selectedDate) == false else { return }
Purrtine/Models/TaskCalendarPresentation.swift|calendar.isDate(occurrence, inSameDayAs: date) else {
Purrtine/Models/TaskFormPersistence.swift|if let schedule = task.schedules.first(where: { $0.isActive }) ?? task.schedules.first {
Purrtine/Models/TaskFormPersistence.swift|schedule.scheduledDate = draft.scheduledDate
Purrtine/Utilities/CatDeletionService.swift|.filter { $0.assignedCats.count <= 1 }
Purrtine/Utilities/TaskAssistantInterpreter.swift|return calendar.date(byAdding: .day, value: -1, to: referenceDate)
Purrtine/Utilities/NotificationManager.swift|occurrence = schedule.followingOccurrence(after: dueDate, calendar: calendar)
EOF
if [ "$anchors_ok" -ne 1 ]; then
  echo "The covered code changed. Re-read it, mirror the change in $SPEC.tla, update the anchor"
  echo "list in run.sh and the coverage table in SKILL.md, then run again."
  exit 3
fi
echo "Anchors: the covered code still has every line the model relies on."

# --- 2. Find Java and TLC --------------------------------------------------------------
JAVA_BIN=${JAVA:-}
if [ -z "$JAVA_BIN" ]; then
  JAVA_BIN=$(mise which java --tool java@temurin-25 2>/dev/null || true)
fi
[ -z "$JAVA_BIN" ] && JAVA_BIN=$(command -v java || true)
if [ -z "$JAVA_BIN" ] || ! "$JAVA_BIN" -version >/dev/null 2>&1; then
  echo "No Java 11+ found. Install one (for example: mise install java@temurin-25) or set JAVA."
  exit 4
fi

JAR=${TLA2TOOLS:-}
if [ -z "$JAR" ]; then
  JAR="${XDG_CACHE_HOME:-$HOME/.cache}/tla2tools/$TLC_VERSION/tla2tools.jar"
  if [ ! -f "$JAR" ]; then
    mkdir -p "$(dirname "$JAR")"
    echo "Downloading tla2tools.jar $TLC_VERSION ..."
    curl -fsSL -o "$JAR.part" \
      "https://github.com/tlaplus/tlaplus/releases/download/v$TLC_VERSION/tla2tools.jar" || {
      echo "Download failed. Set TLA2TOOLS to a tla2tools.jar $TLC_VERSION."; exit 4; }
    got=$(shasum -a 256 "$JAR.part" | cut -d' ' -f1)
    if [ "$got" != "$TLC_SHA256" ]; then
      rm -f "$JAR.part"; echo "tla2tools.jar checksum mismatch ($got)."; exit 4
    fi
    mv "$JAR.part" "$JAR"
  fi
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/formal-rcl.XXXXXX")
cp "$SKILL_DIR/$SPEC.tla" "$SKILL_DIR"/*.cfg "$WORK/"
cleanup() { [ "${KEEP:-0}" = 1 ] && echo "Work folder kept: $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

tlc() { # $1 = config file, $2 = output file
  (cd "$WORK" && "$JAVA_BIN" -XX:+UseParallelGC -jar "$JAR" -workers auto \
     -metadir "$WORK/states-$(basename "$1" .cfg)" -config "$1" "$SPEC.tla" >"$2" 2>&1)
}

# --- 3. The gate: rules the code keeps today -------------------------------------------
echo "Gate (promise.cfg): every rule ..."
tlc promise.cfg "$WORK/promise.out"
if grep -q "No error has been found" "$WORK/promise.out"; then
  grep -E "distinct states found" "$WORK/promise.out" | tail -1
  echo "GATE PASS"
else
  echo "GATE FAIL - TLC output:"
  sed -n '/Error:/,$p' "$WORK/promise.out"
  echo "Read it as a path with /statechart on $SPEC.tla and promise.cfg (view.js as the view)."
  exit 1
fi

# --- 4. Known findings: each must still break on its own --------------------------------
status=0
for rule in $KNOWN_FINDINGS; do
  sed '/^INVARIANTS/,$d' "$WORK/findings.cfg" >"$WORK/only-$rule.cfg"
  printf 'INVARIANTS\n    %s\n' "$rule" >>"$WORK/only-$rule.cfg"
  tlc "only-$rule.cfg" "$WORK/only-$rule.out"
  if grep -q "Invariant $rule is violated" "$WORK/only-$rule.out"; then
    echo "KNOWN FINDING still present: $rule"
  elif grep -q "No error has been found" "$WORK/only-$rule.out"; then
    echo "FINDING GONE: $rule now holds. If the code was fixed on purpose, move it to the gate"
    echo "  (promise.cfg) and out of KNOWN_FINDINGS and SKILL.md \"Known findings\"."
    status=2
  else
    echo "TLC did not finish for $rule:"; tail -20 "$WORK/only-$rule.out"; exit 4
  fi
done
exit $status
