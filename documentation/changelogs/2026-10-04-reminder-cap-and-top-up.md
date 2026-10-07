# 2026-10-04 — Reminders capped at 60, rebuilt as one set, topped up on every app open (#80)

iOS keeps only the 64 soonest pending notification requests per app and silently drops the rest.
Each series had its own cap, but nothing bounded the total: the three onboarding starter tasks alone
produced 83 requests. Reminders were also rebuilt only when a task or a setting changed, so a task
nobody touched stopped reminding after about three to four weeks.

## What changed

- **One capped selection.** `CareTaskReminderSelection` (new, pure) keeps the 60 soonest candidate
  reminders across every task, overdue follow-ups included; ties break by identifier. The other 4
  system slots stay free for snoozes.
- **One write path.** `TaskNotificationScheduling` no longer offers per-task schedule or cancel
  calls. Its one rebuild entry point, `resyncAllCareTaskReminders()`, runs the full capped resync
  through `NotificationResyncCoordinator`.
- **The writer keeps its contract.** Every `CareTaskWriting` verb commits, then *awaits* the newest
  full resync, and still throws `CareTaskRemindersOutOfSyncError` when it fails. A pass that a newer
  request cancels is not reported as success: `NotificationResyncCoordinator.resync()` follows the
  chain to the newest pass. This matters for the notification "Complete" action, which runs in the
  background and ends right after the writer returns.
- **Top-up on activation.** `NotificationManager.handleAppActivation()` recounts the badge, refreshes
  the permission, then asks for one full resync. Back-to-back activations coalesce in the
  coordinator.
- **Diff, not wipe.** `resyncCareTaskNotifications(with:)` reads the pending set once, removes only
  care-task requests that are no longer selected, and adds only missing or changed ones. It never
  removes `snooze_` or debug test requests. Identifiers name the occurrence by its due date
  (`<task>_<schedule>_<epoch>`, `<task>_<schedule>_overdue_<epoch>`), not by position.
- **A failed fetch changes nothing.** The coordinator reads through a fresh `ModelContext` (only
  committed state, including commits from other contexts) and throws on a failed fetch instead of
  treating it as "no tasks".
- **Snoozes.** A full resync leaves snoozes alone, so the writer removes a task's pending snoozes
  itself when it completes or deletes the task (`cancelSnoozedNotifications(forTaskId:)`); a snooze
  for a finished occurrence would otherwise fire and invite a second completion. Turning reminders
  off in Settings or in the system removes every care-task reminder *and* every snooze, as before.
- A pass that runs before the first permission read (a cold launch from a notification action)
  reads the permission first, instead of treating "not determined" as "reminders off" and wiping
  the set.
- `resyncAllCareTaskReminders()` asserts in DEBUG when the coordinator hook is not wired, outside
  previews, so a writer cannot silently report success with no resync behind it.

## Measured

One full resync over 50 daily tasks, on the fake notification center, iPhone 12 simulator,
iOS 26.5:

| | Requests added per pass | Time per pass |
| --- | --- | --- |
| Before | 1,550 (iOS kept 64) | 73–86 ms |
| After, first pass | 60 | 123 ms |
| After, later passes | 0 | 74–79 ms |

On a device each add is a call to the system notification service, so the add count is the cost
that matters there. The CPU time stays the same: the fetch has no predicate, and every occurrence
is still computed before the selection.

## Out of scope

- Telling the caregiver to open the app before the 60 reminders run out ([#11](https://github.com/bckizildemir/Purrtine/issues/11), old CatCareCalendar#94).
- The per-series caps and the 12-month scheduling horizon.
- Onboarding still saves each starter task through the writer, so it runs three small full resyncs.
