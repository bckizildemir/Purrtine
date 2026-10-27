# 2026-10-28 — Local "open the app" nudge; reminder cap 60 -> 59 (#11)

The capped reminder set (#80) runs out if the caregiver never opens the app. When the selection is
full, the resync now also schedules one local nudge that asks the caregiver to open the app, which
tops the set up.

## What changed

- `CareTaskReminderSelection.limit` is 59: 59 reminders + 1 nudge slot + 4 snooze slots = 64.
- `NotificationManager.resyncCareTaskNotifications` adds one request with the stable identifier
  `app_open_nudge`, no `taskId`. It is part of the same diff as the reminders, so a resync replaces it,
  and it is removed when reminders are off or the selection holds fewer than 59 reminders.
- Fire date: 24 hours before the last selected reminder. If that is not in the future, there is no
  nudge, so a dense schedule never nudges an active caregiver right after an app open
  (`CareTaskReminderSelection.nudgeFireDate`).
- Tapping the nudge opens the app and routes nowhere: `didReceive` finds no `taskId` and completes.
- `cancelAllCareTaskNotifications` also removes the nudge. Snoozes and debug requests are untouched.
- New strings: `notification.nudge.title`, `notification.nudge.body` (en, tr).

Local only: no server push (owner decision).
