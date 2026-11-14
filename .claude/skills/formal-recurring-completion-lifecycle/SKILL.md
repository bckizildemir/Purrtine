---
name: formal-recurring-completion-lifecycle
description: "Model-check (TLA+/TLC) what completing a recurring Care Task does to its schedules and completions, across every completion path: task list, calendar, Whiskers, the reminder's Complete action, a failed save with CompletionUndo, Edit Task, task and cat delete. Use before and after any change to TaskActionService.recordCompletion / handleRecurringCompletion, CareTaskSchedule.nextOccurrence, CareTaskWriter.complete or CompletionUndo, NotificationActionCoordinator, TaskFormPersistence.updateTask, TaskCalendarView's Complete, or the Whiskers complete flow; or when asked whether a task can get stuck, vanish, or be completed twice."
---

# Formal check: the recurring completion lifecycle

**Promise.** Completing a Care Task either leaves exactly one active schedule pointing to a strictly
later occurrence, or closes the task; a completed occurrence never comes back and is never completed twice.

**Harm when it breaks.** A task stuck on its first date, a task that vanishes, or doubled or missed care:
a second medication dose, or a feeding nobody gives.

TLA+ with TLC was chosen because the question is about the order of events (a reminder action in its own
`ModelContext`, a confirmation that waits in Whiskers, an Edit Task form that is open while something else
commits), which tests rarely line up, and TLC tries every order within the bounds.

## Run

```sh
.claude/skills/formal-recurring-completion-lifecycle/run.sh
```

About 20 s. It needs Java 11+ (`$JAVA`, else `mise which java --tool java@temurin-25`, else `java` on PATH) and
downloads `tla2tools.jar` 1.7.4 once into `~/.cache/tla2tools/` (checksum checked; or set `$TLA2TOOLS`).
No build, no simulator, no network after the first run.

It does three things, in order:

1. **Anchors.** Greps the covered Swift for the exact lines the model relies on. A missing line means the
   code moved away from the model: exit 3.
2. **Gate** (`promise.cfg`): every rule below (plus `TypeOK` and deadlock) over every completion path.
   Must pass. A break is a regression: exit 1.
3. **Known findings** (`findings.cfg`): each rule in `KNOWN_FINDINGS` must still break. The list is empty
   since #141. Add a rule there only for a new finding that waits for a product decision.

Exit 0 means: code matches the anchors and every rule holds (about 319,000 states).

**Read every TLC result with the `/statechart` skill**, with `RecurringCompletion.tla`, the config in
question and `view.js` as the view (`--view`). It turns a violation into the shortest path in a caregiver's
words and draws the chart. Use `chart.cfg` for a readable chart of the normal lifecycle (72 states);
`promise.cfg` is too large for a chart (about 319,000 states), so for a gate break read its path in the
report. The saved output is in `charts/lifecycle/`. `/statechart` writes only to a new or empty folder: write to a fresh `--out` folder, then copy `chart.mmd` and `report.md` over.

## The rules

| Rule | In words | Today |
| --- | --- | --- |
| `OneActiveScheduleOrClosed` | An open task has exactly one active schedule; a closed one has none. | holds |
| `NextIsStrictlyLater` | A completion that keeps the task open moves it to a later day than the one completed. | holds |
| `FailedSaveChangesNothing` | When `save()` throws, `CompletionUndo` puts the task back exactly as it was. | holds |
| `CompletedNeverReappears` | The day the task is due again is never a day already completed (unless the caregiver reopened it in Edit Task: moved the date onto or before it). | holds (#141) |
| `NeverCompletedTwice` | No day carries two completions (same exception). | holds (#141) |
| `CompletesTheOccurrenceShown` | The completion is recorded for the day the caregiver saw and confirmed. | holds (#141) |
| `NoOccurrenceSkipped` | No day between the start date and the due day (or the end date, once closed) disappears without a completion. | holds (#141) |

## Fixed findings (#141)

The four paths below broke the rules until #141. The fix is one check every completion path shares,
`TaskActionService.validateOccurrence`, run before anything is recorded (`Valid` in the model):

- a caller that showed the caregiver a day passes it as `expectedOccurrence`, and it must be the open
  day: the reminder (its `userInfo` carries `occurrenceDate`), the Whiskers card (`openOccurrence` when the
  card was made), the task-list row (at the tap) and the completion sheet (when it opened);
- an explicit `completedForDate` (calendar, Whiskers "today"/"yesterday") must not be after the open day
  and must not already have a completion.

A refused completion records nothing and shows "That day is not the one due now" (`CompletionRefused`).

1. **`NoOccurrenceSkipped`**: completing a later day in the calendar (or Whiskers "today" on an overdue
   task) moved the task past today. Now refused.
2. **`CompletesTheOccurrenceShown`**: a reminder's Complete, or a Whiskers card / sheet confirmed after the
   task was completed elsewhere, credited a different day. Now they name their day and are refused when it
   is no longer open.
3. **`CompletedNeverReappears`**: Edit Task saved its opened date over a schedule a reminder had moved.
   Now Save writes the date only when the caregiver changed it (`TaskFormPersistence.updateTask`,
   `openedScheduledDate`).
4. **`NeverCompletedTwice`**: Whiskers recorded the same day twice. Now refused.

Model notes from the fix: the ghost `moved` became a set of reopened days (a move onto or before a
completed day reopens it and every later one), because a single "last move" ghost flagged the
caregiver's own deliberate re-dos. The calendar keeps completing the selected day; a later day is
refused rather than mapped to the open one, which would break `CompletesTheOccurrenceShown`.

## What the model covers

| Model part (`RecurringCompletion.tla`) | Code |
| --- | --- |
| `ActiveI` / `ActiveDay` | `CareTask.activeSchedule` (`Models/CareTask.swift`, `activeSchedules.min`) |
| `NextOccurrence` | `CareTaskSchedule.nextOccurrence(from:calendar:)`: nil when inactive, never before the anchor, nil past `endDate` |
| `CompletionDate` | `TaskActionService.completionDate(for:explicit:)` |
| `Recorded` | `TaskActionService.recordCompletion` + `handleRecurringCompletion` (+1 day, then `nextOccurrence`, then `isActive = false`) |
| `CompletionSaved` | `CareTaskWriter.complete` → `commit` succeeds |
| `CompletionSaveFails` / `Restored` | `commit` catches, `CompletionUndo.restore` |
| `DeliveredRemindersRemoved` | `scheduler.removeDeliveredCareTaskNotifications` after the resync in `complete` |
| `TapCompleteInList` | `TaskManagementView` row → `TaskManagementViewModel.handleCompletionAction` / `submitCompletion` |
| `TapCompleteInCalendar` | `TaskCalendarView.handleTaskCompletion`, `TaskCalendarDerivation.tasksByDate` |
| `AskWhiskersToComplete` | `TaskAssistantViewModel.confirmPendingAction` / `completeDetailedTask`, `TaskAssistantInterpreter.detectCompletionDate`, cloud `"yesterday"` |
| `ReminderFires` | `NotificationManager` reminder series (`followingOccurrence`), `userInfo` with `taskId` and `occurrenceDate` |
| `CompletionSaved("notification")` | `NotificationActionCoordinator.handle(.complete)`: new `ModelContext`, `fetchTask`, `complete` |
| `OpenEditForm` / `SaveEditForm` | `TaskFormPersistence.updateTask` (`schedules.first(where: isActive) ?? schedules.first`, `apply`, date written only when changed) |
| `DeleteTask` / `DeleteCat` | `CareTaskWriter.delete` (cascade); `CatDeletionService.delete` (`assignedCats.count <= 1` deleted, shared kept) |
| `CompletionFindsNoTask` | `fetchTask` → `taskNotFound` |
| `Valid` / `CompletionRefused` | `TaskActionService.validateOccurrence` → `TaskActionError.occurrenceNotOpen` |
| `expect` in a request | `CareTaskCompletionInput.expectedOccurrence`: `TaskCompletionRequest`, `handleCompletionAction`, `TaskAssistantConfirmation.openOccurrence`, `NotificationManager.occurrenceDateKey` |

`run.sh` lists the exact anchor lines per file.

**Sync commit:** `SYNC141` (the #141 fix, 2026-11-14). Before you trust a result, run
`git log --oneline SYNC141..HEAD -- Purrtine/Utilities/TaskActionService.swift Purrtine/Models/CareTask.swift Purrtine/Utilities/CareTaskWriter.swift Purrtine/Utilities/NotificationActionCoordinator.swift Purrtine/Views/Tasks/TaskCalendarView.swift Purrtine/Models/TaskCalendarPresentation.swift Purrtine/Models/TaskFormPersistence.swift Purrtine/Models/TaskManagementViewModel.swift Purrtine/Models/TaskAssistantViewModel.swift Purrtine/Utilities/TaskAssistantInterpreter.swift Purrtine/Utilities/CatDeletionService.swift Purrtine/Utilities/NotificationManager.swift`.
Any commit listed may have changed what the model describes, even when the anchors still match. Move the
sync commit forward only after you re-read those changes and confirm the model still describes them.

## Bounds and assumptions

- One daily task (interval 1), days 0..2, end date on day 2, two cats (`promise.cfg`, `findings.cfg`); at most
  2 completions and 2 open requests at once (`Bounds`). `.once` and other frequencies are not modeled: the
  lifecycle only needs `nextOccurrence` to be monotone and never earlier than the anchor, which they share.
- **One commit is one step.** `recordCompletion` and `save()` run on the main actor with no `await` between them
  (`CareTaskWriter.commit`), and the reminder path fetches and commits in the same step.
- **Shared-store assumption.** Every commit reads the store as it is now: the main context sees a save made
  by `NotificationActionCoordinator`'s own context. If SwiftData did not merge it, the in-app paths would act on
  a stale task, which the model does not explore (finding 3 depends on the merge).
- Edit Task is modal: while it is open only a reminder action can complete (`OnScreen`). The list sheet and the
  calendar share one `taskCompletionRequest`. The caregiver picks a new date from today on, or keeps the shown one.
- A completion reaching a deleted task writes nothing. For the reminder path this is `taskNotFound`; for a stale
  main-context object (Whiskers holding a deleted task) it is an assumption, not measured.
- Left out: a delete whose commit failed and stays staged, then a completion's `save()` lands it; reminder
  contents and the resync itself (see `formal-reminder-resync-consistency` if present); times of day and time
  zones (the engine's DST tests own those); `isOnTime`, photos, caregivers, notes; snooze.
- The findings are traced through the code line by line, not replayed in a running app or a unit test.

## When a change touches this code

1. Run `run.sh` before and after.
2. Exit 3 (anchor gone): read the new code. If behavior changed, change the matching part of
   `RecurringCompletion.tla` (table above), then the anchor in `run.sh`, then this file. Keep every model step
   one indivisible step in the code.
3. Exit 1: read the path with `/statechart` (`promise.cfg`). Replay it against the code one action per step.
   If the code really does that, it is a regression. If it does not, the model is wrong: fix the model and say so.
4. Never weaken a rule or remove a source to make the gate pass.
5. Re-save `charts/lifecycle/` with `/statechart` (`chart.cfg`)
   and move the sync commit forward.

## How it was proven able to fail (2026-11-12)

- Scratch change in `TaskActionService.handleRecurringCompletion`: `.date(byAdding: .day, value: 0, …)` (the
  old "measure from the completed day" bug that pinned a task to its first date). `run.sh` stopped at the
  anchor check (exit 3). Mirrored in the model (`NextOccurrence(scheds[a], cfd)`), the gate failed on
  `NextIsStrictlyLater`: complete day 0 from the list, the task is due day 0 again.
- Scratch change in `CompletionUndo.restore`: removed `activeSchedule?.isActive = wasActiveScheduleActive`.
  Anchor check exit 3; mirrored in `Restored`, the gate failed on `FailedSaveChangesNothing` (and
  `OneActiveScheduleOrClosed`): a failed save leaves an open task with no active schedule (it vanishes from Today).
- Both scratch changes were dropped; `run.sh` is back to exit 0.
