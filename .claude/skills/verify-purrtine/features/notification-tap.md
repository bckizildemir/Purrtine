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
  field the tap handler reads. Not proved: that the slim profile lets `simctl push` through.
- **B: a real local reminder due soon.** Tasks "+" → Custom Task (see `add-task.md`): title `Soon task`,
  pick the cat, Repeat Once, switch Time on and set the time 2 to 3 minutes ahead (wheel picker; the
  Time row's subtitle shows the chosen time, assert it), reminder "On time". Save with `taskAdd.saveButton`
  (`vp tap --once`). `vp reminders "Soon task"` counts 1. Wait for the minute; the banner shows. Not
  proved: setting the wheel with axe (try `axe swipe` on the minute wheel from its frame in `vp ui`).

Steps:

- **Banner.** Within 5 s of delivery read `vp ui`: a SpringBoard element with the title/body text shows
  (title "Care task reminder | Bakım görevi hatırlatması", with a category emoji for a real local
  reminder; body is the task title and cat names). `vp shot reminder-banner`. If `vp ui` shows no banner,
  locate it in the screenshot (top of the screen) and tap its centre with
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
