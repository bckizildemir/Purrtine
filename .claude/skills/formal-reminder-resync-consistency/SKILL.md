---
name: formal-reminder-resync-consistency
description: Model-check (TLA+/TLC) that Purrtine's pending care-task reminders converge to the set derived from the saved tasks, inside iOS's 64-slot cap, and that no reminder or snooze outlives the occurrence or task it is for. Use when a change touches the reminder resync, snoozes, the CareTaskWriter verbs (save, delete, complete, snooze), cat deletion, NotificationActionCoordinator, the resync triggers (settings, permission, app activation) or CareTaskReminderSelection, or when asked whether reminders can go stale, go missing or overflow.
---

# Formal check: reminder resync consistency

**Property.** Once nothing is in flight, the pending local notifications are exactly the reminders
(plus the "open the app" nudge) derived from the saved, active schedules, within the 64-slot cap
(59 reminders + 1 nudge + 4 snoozes); a completed or deleted occurrence never fires; a snooze never
outlives its occurrence; reminders off means nothing pending; a failed store read never changes the set.

**Harm.** A caregiver silently misses a reminder, or gets a stale one and completes the same
occurrence twice.

Tool: TLA+ with TLC (a model checker), because the question is whether async steps can run in a bad
order. The model is `ReminderResync.tla`; each action names the Swift code it stands for, at the
granularity the code awaits.

## Does my change touch this?

Yes when you change any of these (the coverage record):

| Model action | Code |
| --- | --- |
| `PassFetch`, `PassAuth`, `PassRead`, `PassApply`, `PassAdd`, `Request` | `NotificationResyncCoordinator.scheduleResync` / `resync` / `resyncNow` / `activeScheduleInfos`; `NotificationManager.resyncCareTaskNotifications`, `selectedReminderCandidates`, `isCareTaskReminder`/`isNudge`/`isSnooze` |
| `Derived` | `CareTaskReminderSelection.soonest` (limit) and `nudgeFireDate` (nudge only when the set was cut) |
| `Complete` + `CancelSnoozesRead`/`Remove` | `CareTaskWriter.complete`, `NotificationManager.cancelSnoozedNotifications` (generation bump, then its turn in `inSnoozeQueue`) |
| `DeleteTask` | `CareTaskWriter.delete`, including the failed-commit path and `watchForStagedDelete` (`StagedDeleteWatch`) |
| `EditSchedule` | `CareTaskWriter.save` (and the staged-delete watch it fires) |
| `DeleteCat` | `CatDeletionService.delete` (cascade, then `refreshReminders`, which cancels the snoozes of touched tasks the store no longer holds, then resyncs) |
| `SnoozeTap`, `SnoozeAdd`, `SnoozeRead`, `SnoozeCommit` | `NotificationActionCoordinator.handle(.snooze)` (no await before the fetch), `CareTaskWriter.snooze` (refuses a staged delete), `NotificationManager.scheduleSnoozedNotification` (generation, reminders-on guards, `inSnoozeQueue`, the snooze cap) |
| `ToggleSettings`, `AppActivation`, `LaunchPermissionCheck`, `RefreshPerm` | `NotificationManager.applySettings`, `handleAppActivation`, `checkAuthorizationStatus`, `refreshAuthorizationStatusFromSystem`; wiring in `PurrtineApp.init` |

Files: `Purrtine/Utilities/NotificationResyncCoordinator.swift`, `NotificationManager.swift`,
`CareTaskReminderSelection.swift`, `CareTaskWriter.swift`, `NotificationActionCoordinator.swift`,
`CatDeletionService.swift`, `StagedDeleteWatch.swift`, `Purrtine/PurrtineApp.swift`.

Sync commit: `SYNC_PLACEHOLDER` (2026-11-14, #142). The model was last confirmed
to describe the code at this commit. `run.sh` lists the covered files that changed since then.
Move the sync commit forward only after you re-read the changed functions and confirmed (or fixed)
the model at the new commit.

## Run

```sh
.claude/skills/formal-reminder-resync-consistency/run.sh
```

It needs Java 11+ and `tla2tools.jar` 1.7.4 (TLC 2.19); set `TLA2TOOLS` (and `JAVA`) or let it find
the copy the `/statechart` skill installs with mise. It runs every rule of both configs, one TLC run
per rule, in about two minutes on this Mac, and prints `holds` / `breaks (known finding)` / `BREAKS (NEW)` /
`HOLDS (was a known finding)`. Exit 0 means the result is the known one.

Two configs, to keep each run short:

- `ReminderResync-resync.cfg`: no snoozes; complete, delete (commit lands or fails and stays
  staged), edit, cat delete, settings toggle, permission change, app activation, cold launch with the
  permission not yet read, one failed store read; 4 events. Rules: `ConvergesToStore`,
  `OffMeansSilent`, `FailedReadKeepsSet`, `WithinIOSCap`.
- `ReminderResync-snooze.cfg`: the same events plus up to 2 snoozes, 3 events, no failed read.
  Rules: `NoSnoozeAfterCompletion`, `NoSnoozeForDeletedTask`, `OffMeansSilent`,
  `SnoozesWithinSlots`, `WithinIOSCap`.

Bounds: 2 tasks (task 1 is on the deletable cat only), a reminder limit of 1 for 59, 1 snooze slot
for 4, so the cap is 3 for 64.

## Charts

No charts are kept: every rule holds, and both state graphs are far over the chart budget. To read a
new break, run `/statechart` on the spec, the per-rule cfg `run.sh` wrote (its `TLC output` folder)
and `view.ts`.

## Read a result

Read every break with the `/statechart` skill, on `ReminderResync.tla`, the config, and the view
`view.ts` in this folder. It gives the shortest path to each broken rule in plain words. Then decide:

- **Real bug**: replay the path against the code, one action per step (the table above names the
  code). If every step is something the code can do in that order, it is a bug: report it with the
  path in the code's words. Do not weaken the rule.
- **Modeling error**: a step the code cannot take (for example an `await` the model splits that the
  code does not, or a check the code makes that the model skips). Fix the model, note it in the
  commit, and run again.
- `HOLDS (was a known finding)`: the code was fixed (move the finding out of `known` in `run.sh` and
  out of the list below), or the model drifted from the code.

When you change covered code on purpose, change the matching action in the model in the same PR, run
`run.sh`, and move the sync commit.

## Findings

None open at the sync commit; `known` in `run.sh` is empty. Fixed in #142 (each was a real path in
the code):

1. **A snooze outlived a completion** (`NoSnoozeAfterCompletion`): the snooze's add awaited the
   permission check while the occurrence was completed. Now `cancelSnoozedNotifications` bumps a
   per-task generation at once, and the snooze stands down when it sees the bump; adds and cancels
   run one at a time in `inSnoozeQueue`. The coordinator's own permission await before the fetch
   is gone: the model, with the ghost occurrence taken at the tap, showed a completion during it
   tagged the snooze to the next occurrence (found by the review of the first draft).
2. **A snooze outlived a deleted task** (`NoSnoozeForDeletedTask`): cat delete never cancelled
   snoozes, and a snooze tapped while a failed task delete was staged still landed. Now the resync
   drops snoozes of tasks with no active schedule, `refreshReminders` cancels the snoozes of touched
   tasks the store no longer holds (catches a snooze add already in the queue), and
   `CareTaskWriter.snooze` refuses a task whose delete is staged. The model found the last two after
   the first draft of the fix.
3. **Reminders off was not silent** (`OffMeansSilent`): the snooze path checked only the iOS
   permission. Now it checks the resync's own test (settings and the permission as the app last read
   it) before and inside the queue. The model found the in-queue race (permission or settings turned
   off while the add waited) after the first draft.
4. **Snoozes had no cap** (`SnoozesWithinSlots`, `WithinIOSCap`): now at most
   `CareTaskReminderSelection.snoozeSlots` (4) pending; a fifth replaces the oldest.

What holds: every rule of both configs (resync: about 2.2 million states; snooze: about 340,000).

## What the model leaves out

- Time. Reminders do not fire in the model, so the short window between a commit and the end of its
  resync (a reminder for a just-completed occurrence can still fire) is not checked; the rules look
  at states where nothing is in flight.
- Fire dates, recurrence and the 12-month horizon: each open task offers one reminder candidate,
  and the lower task number is "sooner". The nudge is wanted exactly when the limit cut the set; its
  date and the cut-by-horizon case are not modeled. Overdue follow-ups are not modeled.
- Delivered notifications, the badge, and debug test notifications.
- `CareTaskWriter.save` of a new task, onboarding, `DebugDataService`; a failed commit of complete or
  save (their undo leaves nothing staged); a failed cat-delete commit (same shape as a task delete).
- iOS's own behavior past 64 (it keeps the soonest 64 and drops the rest): the model only counts.
- The in-app screens run one verb at a time, and a verb does not wait for its resync before the next
  one starts (a superset of what the screens allow).
