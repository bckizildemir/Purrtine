# 2026-10-28 — Local "open the app" nudge; reminder cap 60 -> 59 (#11)

The capped reminder set (#80) runs out if the caregiver never opens the app. When reminders were cut
short, the resync now also schedules one local nudge that asks the caregiver to open the app, which
tops the set up.

Reminders are cut short in two ways: the 59 limit drops the later ones, or a series' own cap stops it
before its natural end (daily 30, weekly and biweekly 12, monthly 6, custom 20).

## What changed

- `CareTaskReminderSelection.limit` is 59: 59 reminders + 1 nudge slot + 4 snooze slots = 64.
- `NotificationManager.resyncCareTaskNotifications` adds one request with the stable identifier
  `app_open_nudge`, no `taskId`. It is part of the same diff as the reminders, so a resync replaces it.
  It is removed when reminders are off or when nothing is cut (for example a one-off or a series that
  ends on its own inside its cap).
- Fire date (`CareTaskReminderSelection.nudgeFireDate`): 24 hours before the EARLIEST of the last
  selected reminder and the last reminder of every series its own cap cut short. The nudge is scheduled
  whenever any series is cut, not only when the set is full.
- When that moment is already past (the earliest end is less than 24 hours away), the nudge fires at the
  midpoint between now and that earliest end. If the earliest end is not after now, or the midpoint would
  not be in the future, there is no nudge. Each resync moves the nudge, so it does not fire after every
  app open.
- `calculateReminderOccurrences` now reports, per series, the last produced fire date when its cap cut it
  short. A stop at the scheduling horizon or a natural end is not a cut.
- Tapping the nudge opens the app and routes nowhere: `didReceive` finds no `taskId` and completes.
- `cancelAllCareTaskNotifications` also removes the nudge. Snoozes and debug requests are untouched.
- New strings: `notification.nudge.title`, `notification.nudge.body` (en, tr).

Local only: no server push (owner decision).
