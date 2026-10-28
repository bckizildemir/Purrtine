# Add a task

A user adds a custom care task for a cat, with a repeat and a reminder. The task shows in the Tasks
list and, when it is due today, on Home. Proved on 2026-10-14 (iPhone 12, iOS 26.5, English) and on 2026-10-15 (iPhone 12, iOS 27.0, English,
`~/verify-evidence/purrtine/2026-10-15-014147-3a31/`) with a
daily task: the list shows it, and its reminders share the app's 60-reminder cap with the other tasks.

## Sub-features

- `task-add-custom` opens the empty Add Task form from the Tasks "+" menu → Custom Task.
- `task-add-template` opens the template list from the Tasks "+" menu → Add from Template.
- `task-save` saves a titled task for the selected cat. Save fails without a title or without a cat.
- `task-reminder` sets the reminder ("Notifications | Bildirimler" menu: On time, 15 minutes before,
  30 minutes before, 1 hour before, 1 day before; Turkish "Görev zamanında", "15 dakika önce", …) and
  schedules real local notifications.
- `task-required` refuses to save without a title ("Task title is required | Görev başlığı zorunludur").

## How to get to it (user POV)

- Tasks | Görevler tab → "+" (top bar) → "Custom Task | Özel Görev" or "Add from Template | Şablondan Ekle".
- Home tab → "+" → "Add Task | Görev Ekle".
- Home tab → Quick Actions (Feeding, Water, Litter open a template; Custom Task opens the empty form).
- Long-press a cat card → add a task: the only entry that preselects a cat.

## Driving it with axe

Preconditions:

- Onboarding is done with a cat, so the Tasks "+" menu shows (it is hidden while no cat exists).
- No task titled `Brush coat` exists.

- **Open the Tasks tab.** `vp tap --label Tasks --element-type RadioButton` (Turkish: `Görevler`).
- **Open the form.** `vp tap --id taskManagement.addMenuButton`, then
  `vp tap --id taskManagement.customTaskButton`. The heading reads "Add Task | Görev Ekle". Defaults:
  `taskAdd.titleField` shows the placeholder `Task name`, Date `Today`, the time is off
  (`Enable Time` value 0), `Repeat, Once`, `taskAdd.catsButton` value `Not Selected`, and
  `reminderRow.notificationsMenu` reads `Notifications, On time`.
- **Enter the title.** `vp tap --id taskAdd.titleField`, then `axe type 'Brush coat' --udid $UDID`.
- **Pick the cat.** `vp tap --id taskAdd.catsButton` opens a selection sheet:
  `taskCatsSelection.assignAllToggle`, one `taskCatsSelection.cat.<name>` row per cat, and
  `taskCatsSelection.doneButton` (disabled until a cat is picked). `vp tree task-cats-sheet`, then
  `vp tap --once --id taskCatsSelection.cat.Miso` and `vp tap --id taskCatsSelection.doneButton`. The Cats row
  now has the value `Miso`.
- **Repeat daily.** `vp tap --label 'Repeat, Once' --element-type PopUpButton`, then
  `vp tap --label Daily --element-type Button` (options: Once, Daily, Weekly, Every 2 Weeks, Monthly,
  Custom). The row reads `Repeat, Every day`. A daily task always has a next occurrence, so it gets
  reminders; see Gotchas for a `Once` task.
- **Save.** `vp shot task-form-filled`, `vp tree task-form-filled`, then `vp tap --once --id taskAdd.saveButton`.
- **Proof.** The Tasks list holds `taskRow.complete.Brush coat` (value `Pending`) and
  `taskRow.Brush coat` (`Brush coat, Miso, Today`). `vp shot tasks-list` and `vp tree tasks-list`.
- **Side effect: reminders.** `vp reminders "Brush coat" "Daily Feeding" "Refresh Water"`. On 2026-10-14
  after onboarding (two daily tasks) it read `60 requests`, 20 for each title: the app keeps the 60
  soonest reminders across all tasks, so a new daily task takes a share of the cap. Proof: `Brush coat`
  has a count above 0 and the total stays 60.
- **Record.** `echo "feature=add-task entry=tasks-plus-custom result=pass" >> <evidence>/run.txt`.

## Gotchas

- No cat is preselected, even with one cat: the Cats row reads `Not Selected` until you pick one, and
  Save then fails. Only the cat card's entry preselects a cat.
- The Cats row opens a sheet, not a pushed list: close it with `taskCatsSelection.doneButton`.
- A `Once` task with the time off is due at the moment the form opened, which has passed when you save,
  so it gets no reminder and `vp reminders` counts 0. Use `Daily`, or turn the time on and set a future time.
- A reminder needs notification permission. If onboarding skipped it, the form still saves, but no
  notification is scheduled.
- The Repeat menu and the form tree also hold the Tasks list behind the sheet; match by label and
  element type, and read `vp ui` after each tap.
- With more than one cat selected, completing the task later opens a sheet to pick which cat; with
  one cat it completes at once.
