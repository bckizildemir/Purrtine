# Add a task

A user adds a custom care task for a cat, with a time and a reminder. The task shows in the Tasks
list and, when it is due today, on Home. Not yet driven by a verify run (drafted 2026-10-14 from the
source); the first run that drives it corrects this file.

## Sub-features

- `task-add-custom` opens the empty Add Task form from the Tasks "+" menu → Custom Task.
- `task-add-template` opens the template list from the Tasks "+" menu → Add from Template.
- `task-save` saves a titled task for the selected cat.
- `task-reminder` sets the reminder ("Notifications | Bildirimler" menu) and schedules a real local
  notification.
- `task-required` refuses to save without a title ("Task title is required | Görev başlığı zorunludur").

## How to get to it (user POV)

- Tasks | Görevler tab → "+" (top bar) → "Custom Task | Özel Görev" or "Add from Template | Şablondan Ekle".
- Home tab → "+" → "Add Task | Görev Ekle".
- Home tab → Quick Actions (Feeding, Water, Litter, Custom Task).

## Driving it with axe

Preconditions:

- Onboarding is done with a cat, so the Tasks "+" menu shows (it is hidden while no cat exists).
- No task titled `Brush coat` exists.

- **Open the Tasks tab.** `vp tap --label Tasks --element-type RadioButton`
  (Turkish: `Görevler`). The starter tasks from onboarding show.
- **Open the form.** `vp tap --id taskManagement.addMenuButton`, then
  `vp tap --id taskManagement.customTaskButton`. The form title reads
  "Add Task | Görev Ekle".
- **Enter the title.** `vp tap --id taskAdd.titleField`, then `axe type 'Brush coat' --udid $UDID`.
- **Pick the cat.** `vp tap --id taskAdd.catsButton`, tap the cat's
  name by label, and return. The Cats row shows the cat's name.
- **Set the reminder.** `vp tap --id reminderRow.notificationsMenu` and
  pick a lead time by label.
- **Save.** `vp shot task-form-filled`, then `vp tap --id taskAdd.saveButton`.
- **Proof.** The Tasks list holds `taskRow.complete.Brush coat`. `vp shot tasks-list` and `vp tree tasks-list`.
- **Side effect: reminder.** `vp reminders "Brush coat"` copies the device's pending notification store
  into the evidence; a count above 0 proves the reminder was scheduled. A delivered banner needs the
  task's time to pass: set the time two minutes ahead and `vp shot` the banner if the banner itself
  must be proved.

## Gotchas

- The Cats row is a multi-select list, not a picker. Leave it with the back button; check the row
  value after.
- With more than one cat selected, completing the task later opens a sheet to pick which cat; with
  one cat it completes at once.
- A reminder needs notification permission. If onboarding skipped it, the form still saves, but no
  notification is scheduled.
