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
| `Complete` + `CancelSnoozesRead`/`Remove` | `CareTaskWriter.complete`, `NotificationManager.cancelSnoozedNotifications` |
| `DeleteTask` | `CareTaskWriter.delete`, including the failed-commit path and `watchForStagedDelete` (`StagedDeleteWatch`) |
| `EditSchedule` | `CareTaskWriter.save` (and the staged-delete watch it fires) |
| `DeleteCat` | `CatDeletionService.delete` (cascade, then `refreshReminders`) |
| `SnoozeTap`, `SnoozeFetch`, `SnoozeAdd` | `NotificationActionCoordinator.handle(.snooze)`, `CareTaskWriter.snooze`, `NotificationManager.scheduleSnoozedNotification` |
| `ToggleSettings`, `AppActivation`, `LaunchPermissionCheck`, `RefreshPerm` | `NotificationManager.applySettings`, `handleAppActivation`, `checkAuthorizationStatus`, `refreshAuthorizationStatusFromSystem`; wiring in `PurrtineApp.init` |

Files: `Purrtine/Utilities/NotificationResyncCoordinator.swift`, `NotificationManager.swift`,
`CareTaskReminderSelection.swift`, `CareTaskWriter.swift`, `NotificationActionCoordinator.swift`,
`CatDeletionService.swift`, `StagedDeleteWatch.swift`, `Purrtine/PurrtineApp.swift`.

Sync commit: `424ad3cf1220f6aea2a7425bc19a686d0423d44b` (2026-11-12). The model was last confirmed
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

`charts/<rule>/` holds the `/statechart` output (`chart.mmd`, `report.md`, `tlc.out`) for each known
finding, made from `ReminderResync-snooze.cfg` with only that rule and `view.ts`. Make them again with
`/statechart` after a change to the model or the view. The resync config has no chart: it passes, and
its state graph is far over the chart budget.

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

## Findings (known breaks at the sync commit)

Listed in `run.sh` as `known`. Paths are in the model's steps; each was replayed against the code.

1. **A snooze can outlive a completion** (`NoSnoozeAfterCompletion`). You tap "Remind me" on a
   reminder; `NotificationActionCoordinator.handle(.snooze)` fetches the task and then awaits the
   permission check (`scheduleSnoozedNotification` awaits it again). Meanwhile the occurrence is
   completed (in the app, or with Complete on another delivered reminder of the task):
   `CareTaskWriter.complete` commits, `cancelSnoozedNotifications` finds no snooze yet, the resync
   runs. Then the snooze's `add` lands. It fires for an occurrence that is done, and its Complete
   button completes the next occurrence early. Chart: `charts/NoSnoozeAfterCompletion/`.
2. **A snooze outlives a deleted task** (`NoSnoozeForDeletedTask`). Snooze a reminder of a task only
   one cat is on, then delete that cat. `CatDeletionService.delete` lets the `Cat.tasks` cascade
   delete the task and runs a full resync, but never calls `cancelSnoozedNotifications`, and the
   resync leaves snoozes alone while reminders are on. The snooze fires for a task that no longer
   exists; Complete on it fails with `taskNotFound`. The same happens after a failed task delete
   (#7 path): the delete drops the snoozes at once, but a snooze tapped while the delete is still
   staged reads the committed task, lands, and the watch that later lands the delete only resyncs.
   The shortest model path also races the snooze; the plain order (snooze, then delete the cat) breaks
   the rule too. Chart: `charts/NoSnoozeForDeletedTask/`.
3. **Reminders off is not silent** (`OffMeansSilent`). Turn reminders off in Settings; the resync
   removes every reminder and snooze. Then tap "Remind me" on a reminder still in Notification
   Center: the snooze path checks only the iOS permission, never `settings.isEnabled`, so a snooze is
   scheduled and fires. `resyncCareTaskNotifications`'s own comment says off means "the caregiver
   asked for silence". Chart: `charts/OffMeansSilent/`.
4. **Snoozes have no cap** (`SnoozesWithinSlots`, `WithinIOSCap`). Each snooze gets a fresh
   `snooze_<taskId>_<timestamp>` id and nothing limits their number, so a fifth pending snooze makes
   65 requests and iOS silently drops the furthest reminder. Known since issue #93 (closed with this
   item unfixed). Chart: `charts/SnoozesWithinSlots/`.

What holds (resync config, 2 tasks, 4 events, about 2 million states): the pending reminders and
nudge converge to the set derived from the saved tasks after every interleaving of complete,
delete (landed or staged), edit, cat delete, settings, permission, activation, a cold launch with
the permission not yet read, and a pass cancelled by a newer one; reminders off empties the set; a
failed store read leaves the set as it was; the total stays within the cap without snoozes.

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
