# Complete a task

A user ticks a task as done in the Tasks list. A recurring task moves on to its next date (the row
stays `Pending` under "Tomorrow" for a daily task); the completion shows in More → History and in
Home → Routine Status. Proved on 2026-10-14 (iPhone 12, iOS 26.5, English) and on 2026-10-15 (iPhone 12, iOS 27.0, English,
`~/verify-evidence/purrtine/2026-10-15-014147-3a31/`, circle and swipe) with the daily
"Daily Feeding" task.

## Sub-features

- `complete-tap` ticks the row's circle button ("Complete task | Görevi tamamla").
- `complete-swipe` uses the row's leading swipe action "Complete | Tamamla" (swipe right; a left swipe
  shows Delete). It shows only while the task can be completed. Proved 2026-10-14 (second pass).
- `complete-history` shows the completion as a History row with date, time and cat.
- `complete-home` shows it in Home → Routine Status ("Last done today, Due tomorrow").

## How to get to it (user POV)

- Tasks | Görevler tab → the circle on a task row.
- Tasks tab → swipe a row right → "Complete | Tamamla".
- The Home "current tasks" rows only open the Tasks tab, and the Routine Status rows open that task's
  History; neither completes a task.

## Driving it with axe

Preconditions:

- Onboarding is done with a cat and the "Daily Feeding | Günlük Besleme" and "Refresh Water | Su Tazeleme"
  starter tasks (the swipe path uses the second one).

- **Open the Tasks tab.** `vp tap --label Tasks --element-type RadioButton`.
- **Before.** `taskRow.complete.Daily Feeding` has the value "Pending | Bekliyor" and
  `taskRow.Daily Feeding` reads `Daily Feeding, Miso, Today`. `vp shot tasks-before`, `vp tree tasks-before`.
- **Complete.** `vp tap --once --id 'taskRow.complete.Daily Feeding'`
  (Turkish: `taskRow.complete.Günlük Besleme` — the identifier carries the localized title). No sheet,
  confirm or undo shows (one cat). The row moves under the heading `Tomorrow`: `taskRow.Daily Feeding`
  reads `Daily Feeding, Miso, Tomorrow`, and its button value stays `Pending`, because the task now waits
  for its next date. The filter chip `Upcoming` gains a count. `vp shot tasks-after`, `vp tree tasks-after`.
- **History.** `vp tap --label More --element-type RadioButton`. If the More tab still shows a screen from an
  earlier drive (for example `cats.view` after Add a cat), `vp tap --id BackButton --element-type Button`
  first. Then `vp tap --id settings.shortcut.history`. The tree holds `history.view` and
  `history.row.Daily Feeding` with today's date, the time and `Miso`. `vp shot history`, `vp tree history`.
- **Home.** `vp tap --label Home --element-type RadioButton`. `home.routineStatus.row.Daily Feeding` reads
  `Daily Feeding, Miso, Last done today, Due tomorrow`. `vp shot home-after`, `vp tree home-after`.
- **Swipe path.** `vp tap --label Tasks --element-type RadioButton`. Read the frame of
  `taskRow.Refresh Water` in `vp ui` and swipe right a short way:
  `axe swipe --start-x 100 --start-y <row mid-y> --end-x 220 --end-y <row mid-y> --duration 0.4 --udid $UDID`.
  A `Button | Complete` shows at the row's leading edge (its id read `checkmark.circle.fill`, the SF Symbol
  name, in `vp ui` on 2026-10-14; the source sets no identifier, so tap by label).
  `vp shot swipe-revealed`, `vp tree swipe-revealed`, then `vp tap --once --label Complete --element-type Button`.
  The row moves under `Tomorrow` like the circle path. `vp shot swipe-completed`, `vp tree swipe-completed`.
  A long swipe completes at once (full swipe is on; from source, not driven).
- **Side effect: reminders.** Completion runs a full reminder resync. `vp reminders` still shows the
  task's title with a count above 0 (its later days); the total stays at the 60 cap.
- **Record.** `echo "feature=complete-task entry=tasks-row-circle result=pass" >> <evidence>/run.txt` and
  `echo "feature=complete-task entry=row-leading-swipe result=pass" >> <evidence>/run.txt`.

## Gotchas

- The button value does not turn "Completed | Tamamlandı" for a recurring task; only a `Once` task ends as
  completed. Assert on the row's date text, History and Routine Status, not on the value.
- The row identifier holds the task title as the user sees it, so it changes with the language and
  with any rename.
- A tab keeps its navigation stack: the More tab reopens on the last screen pushed in it. Go back with
  `BackButton` before you tap a More shortcut.
- An occurrence that went overdue earlier today moves to Tomorrow when completed. An older overdue
  occurrence moves to the day after its own scheduled day, so a task overdue for several days stays
  overdue (`TaskActionService.swift`). A fresh run's onboarding tasks are due today, so the recipe holds.
