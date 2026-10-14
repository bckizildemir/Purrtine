# Complete a task

A user ticks a task as done in the Tasks list. The row shows as completed, and the completion shows
in More → History and in the Home routine status. Not yet driven by a verify run (drafted
2026-10-14 from the source); the first run that drives it corrects this file.

## Sub-features

- `complete-tap` ticks the row's circle button ("Complete task | Görevi tamamla").
- `complete-swipe` uses the row's swipe action "Complete | Tamamla".
- `complete-history` shows the completion as a History row.
- `complete-home` shows it in Home → routine status.

## How to get to it (user POV)

- Tasks | Görevler tab → the circle on a task row.
- Tasks tab → swipe a row left → "Complete | Tamamla".
- The Home "current tasks" rows only open the Tasks tab; they do not complete a task.

## Driving it with axe

Preconditions:

- Onboarding is done with a cat and the "Daily Feeding | Günlük Besleme" starter task.

- **Open the Tasks tab.** `vp tap --label Tasks --element-type RadioButton`.
- **Before.** `vp shot tasks-before`. The row button `taskRow.complete.Daily Feeding` has the value
  "Pending | Bekliyor" in the tree.
- **Complete.** `vp tap --id 'taskRow.complete.Daily Feeding'`
  (Turkish: `taskRow.complete.Günlük Besleme` — the identifier carries the localized title).
  The value turns "Completed | Tamamlandı".
- **History.** `vp tap --label More --element-type RadioButton`, then
  `vp tap --id settings.shortcut.history`. The tree holds
  `history.view` and `history.row.Daily Feeding`. `vp shot history` and `vp tree history`.
- **Home.** `vp tap --label Home --element-type RadioButton`; the routine
  status section `home.routineStatus.section` names the task. `vp shot home-after`.

## Gotchas

- The row identifier holds the task title as the user sees it, so it changes with the language and
  with any rename.
- A recurring task reappears for its next date after completion; assert on the value and on History,
  not on the row disappearing.
