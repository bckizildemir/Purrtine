# Reminder nudge

The app keeps at most 59 care-task reminders pending (iOS allows 64) and rebuilds them on every change.
When something cuts the reminders short, it also schedules one "open the app" notification, "Reminders
are running low | Hatırlatmalar azalıyor", so the user comes back before reminders run out. PR #100
(fix for #93) changed two things: the nudge never fires sooner than one hour from now, and a series
stopped by the 12-month scheduling horizon counts as a cut. The nudge needs notification permission like
every reminder. Not yet proved (written from source 2026-11-07).

## Sub-features

- `nudge-present` a nudge request (identifier `app_open_nudge`, body "Open the app to keep reminders
  going | Hatırlatmaların devam etmesi için uygulamayı aç") is pending when a cut exists: more than 59
  candidate reminders, or a series stopped by its own count cap (daily 30, weekly and every 2 weeks 12,
  monthly 6, custom 20) or by the horizon while it goes on.
- `nudge-date` fires 24 hours before the earliest cut end (the last selected reminder, or the last
  reminder of a cut series); if that is already past, at the midpoint to that end; never sooner than
  now + 1 hour (the #100 floor, both paths).
- `nudge-absent` no nudge when nothing is cut (a series that ends on its own, for example a daily task
  with an end date inside the cap) or when reminders are off or not permitted.
- `nudge-horizon` a series that repeats every 3 months fills 5 slots inside the horizon (0, 3, 6, 9, 12
  months) and gets a nudge; a lone reminder stopped by the horizon gets none.

## How to get to it (user POV)

- Nothing to open: the nudge is a pending notification the app creates after onboarding saves the
  starter tasks, after Add Task, after a completion, and when the app becomes active.
- Reminders on/off: More → Settings → Notifications → "Enable Notifications | Bildirimleri Etkinleştir"
  (`settings.notifications.row`, then the switch; the switch has no identifier).
- Permission is asked in onboarding (`onboarding.notification.enableButton`, system alert "Allow | İzin
  Ver").

## Driving it with axe

Preconditions:

- Onboarding is done with notification permission **allowed** and Daily Feeding and Refresh Water ticked
  (see [Onboarding](./onboarding.md)). Data only from user screens.
- `vp reminders` reads the first pending store on the device; on a fresh device it is the app's.

Steps:

- **Nudge present after onboarding.** `vp reminders "Daily Feeding" "Refresh Water" app_open_nudge`.
  Two daily tasks give 60 candidates (30 each), more than 59, so the set is cut by the limit. Assert the
  total is `60 requests` (59 reminders plus the nudge), `app_open_nudge` counts 1, each task title counts
  a positive number, and the two title counts add to 59. Both daily series are also cut by their cap of
  30. (Earlier recipes saw `60 requests` for two tasks; the split between titles may differ by one.)
  If `app_open_nudge` counts 0 while the total is 60, the identifier is not in the text the counter reads:
  open the copied store (`<evidence>/NN-pending-notifications.json` or `.plist`) and search it for
  `app_open_nudge` and "Reminders are running low".
- **Nudge date.** The store copy holds the request's trigger as calendar components (year, month, day,
  hour, minute). Find the dictionary next to `app_open_nudge` (`plutil -p <copy>` or
  `/usr/bin/python3 -I` with `plistlib`; the store is a keyed archive, see `scripts/count-pending.py` for
  how it is walked). Compute from the same copy the latest fire date among the selected reminders (the
  other requests' triggers). Assert nudge = earliest cut end − 24 h, to the minute, and nudge ≥ now + 1 h.
  For two daily tasks the earliest cut end is about day 29 or 30 from today, so the nudge is about
  28 to 29 days away. Not proved: the exact keys inside the archive. If you cannot decode the date, say
  so and assert only presence, count and the title text.
- **Floor.** The #100 floor (a set whose last reminder is minutes away) cannot be reached from user
  screens on a fresh device; unit tests cover it (`CareTaskReminderSelectionTests`). Say so in the
  report; do not claim it.
- **Reminders off removes it.** `vp tap --label More --element-type RadioButton` (back out with
  `BackButton` if the tab shows an old screen), `vp tap --id settings.appSettings.row`,
  `vp tap --id settings.notifications.row`. Switch off "Enable Notifications" (`vp tap --once --label
  "Enable Notifications" --element-type Switch`; read `vp ui` for the real type). Then
  `vp reminders app_open_nudge "Daily Feeding"`: assert 0 requests (turning reminders off removes every
  care-task reminder and the nudge, per `NotificationManager`'s resync). Switch it on again and assert the
  counts return to 60 / 1.
- **No nudge when nothing is cut.** Needs a pass with only a series that ends on its own. From user
  screens: Tasks tab, delete the starter tasks (swipe a row left, Delete; confirm in `vp ui`), add one
  `Once` task with its time on and a time at least 2 hours ahead (see `add-task.md`; the time wheel is
  the Time row's expanded picker, its subtitle shows the chosen time), then `vp reminders app_open_nudge`
  reads `1 requests` for the task and 0 for the nudge. Not proved: the delete gesture and the wheel.
- **Horizon (optional).** Add a task with Repeat → Custom → every 3 months (`CustomRepeatSheet`, no
  identifiers in the source: read `vp ui`) after deleting the other tasks. Expect 5 reminders and a nudge
  about 24 hours before the fifth. Not proved.
- **Skipped permission.** On a device whose onboarding used "Skip for now | Şimdilik geç", `vp reminders`
  shows no store or 0 requests and no nudge. A separate fresh run; record it only if the pass has time.
- **Record.** `echo "feature=reminder-nudge entry=onboarding-two-daily result=pass" >> <evidence>/run.txt`.

## Gotchas

- A nudge is a request in the same pending store; `vp reminders` counts requests whose text holds a given
  string, so pass `app_open_nudge` and the notification title if one does not count.
- The store updates a moment after a save. Read it again if the total is below 60 right after a save.
- Completion and Add Task each run a full resync, so the nudge moves; compare dates between two reads
  instead of treating one date as fixed.
- Time-based claims (24 h, 1 h floor) depend on the device clock, which follows the Mac.
- Run on the iOS 27.0 slim device only; local notifications are never disabled by the slim profile.
