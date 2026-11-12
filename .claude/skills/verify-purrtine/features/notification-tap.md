# Notification tap

A user taps a delivered care-task reminder and the app opens on that task: the Tasks tab with the Edit
Task sheet for the task in the notification. Tapping the "open the app" nudge only opens the app. Not yet
proved (written from source 2026-11-07).

## Sub-features

- `tap-reminder` the default tap on a task reminder: `NavigationRouter` selects the Tasks tab and
  `TaskManagementView` presents `TaskEditView` ("Edit Task | Görevi Düzenle") for the task id.
- `tap-nudge` the nudge has no task id: the app comes forward and stays on the screen it was on.
- `tap-action` the banner actions (Complete, Remind in 10 min, Remind in 30 min, Remind in 1 hour) run
  the action without opening a screen. Optional; hard to drive.

## How to get to it (user POV)

- A reminder banner or a Notification Centre entry for a task, delivered while the app is open, in the
  background or closed. A banner shows in the foreground too (`willPresent` returns banner and sound).
- The task needs a reminder that is due: scheduled by Add Task or onboarding, due in the future.

## Driving it with axe

Preconditions:

- Onboarding is done with notification permission allowed; the starter task "Refresh Water" exists. Data
  only from user screens.
- The task's id, read from the pending store (see below).

Delivering a reminder, two ways:

- **A: simctl push (deterministic, preferred).** Read the task id: run `vp reminders "Refresh Water"`; it
  copies the pending store to `<evidence>/NN-pending-notifications.(json|plist)`. A request's identifier
  starts with the task's UUID, then `_` and the schedule's UUID. Get the first one for that title:
  `/usr/bin/python3 -I -c` with `plistlib` over the copy, as in `scripts/count-pending.py`, printing the
  strings of the request that contains `Refresh Water` and matching `[0-9A-F]{8}-[0-9A-F-]{27}`. Then write
  `/tmp/vp-push.json` outside the repo:
  `{"aps":{"alert":{"title":"Care task reminder","body":"Refresh Water"},"category":"TASK_REMINDER"},"taskId":"<uuid>"}`
  and run `xcrun simctl push "$UDID" com.berkecankizildemir.CatCareCalendar /tmp/vp-push.json`. A remote
  payload's custom top-level keys arrive in `userInfo`, so `userInfo["taskId"]` is set; this is the only
  field the tap handler reads. Proved 2026-11-07: `simctl push` with `taskId` works on the slim device.
- **B: a real local reminder due soon.** Tasks "+" → Custom Task (see `add-task.md`): title `Soon task`,
  pick the cat, Repeat Once, switch Time on and set the time 2 to 3 minutes ahead (wheel picker; the
  Time row's subtitle shows the chosen time, assert it), reminder "On time". Save with `taskAdd.saveButton`
  (`vp tap --once`). `vp reminders "Soon task"` counts 1. Wait for the minute; the banner shows. Not
  proved: setting the wheel with axe (try `axe swipe` on the minute wheel from its frame in `vp ui`).

Steps:

- **Banner.** Within 5 s of delivery read `vp ui`: a SpringBoard element with the title/body text shows
  (title "Care task reminder | Bakım görevi hatırlatması", with a category emoji for a real local
  reminder; body is the task title and cat names). `vp shot reminder-banner`. If `vp ui` shows no banner,
  the banner is not in the axe tree (measured 2026-11-07): tap its centre, about (140,72) points, within 2 s of the push or it is gone, with
  `axe tap -x X -y Y --tap-style physical --udid $UDID` (points = pixels / scale, see `cat-photo.md`).
- **Start from a non-Tasks screen** so the jump is visible: stay on Home. `vp tap --label Home --element-type RadioButton`.
- **Tap.** `vp tap --once --label "<banner label>"` or the coordinate tap. Assert, in `vp ui`: the Tasks
  tab is selected, and the sheet holds `taskEdit.titleField` with value `Refresh Water` (Turkish
  `Su Tazeleme`), `taskEdit.saveButton` and `taskEdit.cancelButton`. `vp shot reminder-opened`,
  `vp tree reminder-opened`. Close with `taskEdit.cancelButton` (it may ask to discard only after a change).
- **Cold start.** `xcrun simctl terminate "$UDID" com.berkecankizildemir.CatCareCalendar`, deliver again
  (method A), tap the banner on the lock/home screen: the app launches and the same sheet shows. Not
  proved; `vp doctor` after, the app launched by the tap has no launch arguments either.
- **Nudge tap.** Deliver the nudge by method A with `{"aps":{"alert":{"title":"Reminders are running low","body":"Open the app to keep reminders going"}}}`
  (no `taskId`). Tap the banner: the app stays where it was, no sheet opens.
- **Wrong id.** Method A with a random UUID: the app opens the Tasks tab; no sheet (`CareTask not found`
  is only printed).
- **Record.** `echo "feature=notification-tap entry=push-taskId result=pass" >> <evidence>/run.txt`.

## Gotchas

- A foreground banner is a real banner; tapping it routes like a tap on a background one.
- `willPresent` also syncs the badge count; the app icon badge is not visible in the tree.
- The Edit sheet opens on the Tasks tab even when the task belongs to a filtered-out view: the router
  sets list mode.
- A pushed (remote) banner is not a pending local request, so `vp reminders` does not show it. Prove the
  tap from the screen, not from the store.
- Notification actions (long-press the banner, "Complete") hit `NotificationActionCoordinator` and show
  as a History row; the expanded banner may not be readable by axe. Skip unless the change is about it.
- Never use More → Developer Tools "Send Test Notification" (Debug-only, forbidden by the skill rules).
- Measured 2026-11-07 (English and Turkish): the pending store has no title-to-id order, so the first task id
  from the store opened "Günlük Besleme", not the task you wanted. Map the title to its id first (decode the request
  that holds the title) before you push.
- `/tmp/vp-dump.py`-style decoding: the request's `TriggerDateComponents` holds `NS.year`, `NS.month`, `NS.day`,
  `NS.hour`, `NS.minute`.
- Proved 2026-11-12: `simctl push` with `taskId` of Refresh Water (found by reading the title next to the id in the copied store: ids in the plist belong to the next strings, e.g. 8AB54682… was Daily Feeding) while on Home; the banner was not in the tree; `axe tap -x 140 -y 72 --tap-style physical` within 1.2 s opened Tasks with `taskEdit.titleField` = Refresh Water (`taskEdit.notesField`, `taskEdit.caregiverButton` also present). The pending store also holds `<taskId>_<scheduleId>_overdue_<ts>` requests (overdue reminders).
- Source, not driven: the Snooze action schedules `snooze_<taskId>_<unix ts>` (`NotificationManager.swift:761`); Complete drops that task's snoozes (:554-568). With "Show task details" off in Advanced Notification Settings (`AdvancedNotificationSettingsView.swift:55`) reminders use generic texts. The label in the app reads "Show task details", not "Show Preview".
