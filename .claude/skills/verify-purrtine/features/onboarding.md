# Onboarding

A first launch on a fresh device shows a four-step onboarding: welcome, notification permission,
the first cat, and starter tasks. When the user finishes, the app saves one cat and one task per
ticked starter, schedules their reminders, and lands on the Home tab. Every other feature starts
from the data this journey creates. Proved end to end three times on 2026-10-14 (iPhone 12, iOS 26.5,
English; the last in the maintenance pass) and the Turkish welcome screen on the same day.

## Sub-features

- `onb-welcome` shows the welcome step; "Get Started | Başlayalım" moves on.
- `onb-notify-allow` asks for notification permission through the system alert, only after
  "Enable Notifications | Bildirimleri Etkinleştir".
- `onb-notify-skip` skips the alert with "Skip for now | Şimdilik geç"; the task step then shows "These
  tasks can't remind you yet. | Bu görevler seni henüz hatırlatamaz." with "Allow Notifications | Bildirimlere İzin Ver".
- `onb-cat` saves the first cat's name; "Continue | Devam Et" stays disabled while the name is empty.
- `onb-cat-skip` "I'll add details later | Detayları sonra eklerim" creates no cat.
- `onb-tasks` creates one task per ticked row: Daily Feeding | Günlük Besleme (daily 08:00), Refresh
  Water | Su Tazeleme (daily 10:00), Litter Box Cleaning | Kum Kabı Temizliği (every 2 days, 18:00),
  each with a reminder 15 minutes before.
- `onb-finish` "Start Tracking | Takibi Başlat" lands on Home with the new tasks under "Today & Overdue".

## How to get to it (user POV)

- The first launch of the app on a device that never ran it. There is no other entry point: a
  device that finished onboarding never shows it again, so a new run needs a new device (`vp start`).

## Driving it with axe

Preconditions:

- A fresh run: `vp start` (add `--lang tr` for Turkish), `vp build`, `vp hold`, `vp install`, `vp launch`.
- `vp ui` shows `Button | Get Started | onboarding.welcome.continueButton` (`Başlayalım` in Turkish).

- **Welcome.** `vp shot onboarding-welcome`, then `vp tap --id onboarding.welcome.continueButton`.
  The progress element reads `Notifications` at `50%`; the step shows `onboarding.notification.enableButton`
  and `onboarding.notification.skipButton`.
- **Permission.** `vp shot onboarding-notifications`, then
  `vp tap --id onboarding.notification.enableButton`. The tree now holds the SpringBoard alert: a
  `Sheet` labelled `“CatCareCalendar” Would Like to Send You Notifications` with buttons `Allow` and
  `Don’t Allow` (curly apostrophe). `vp shot notification-alert`, then
  `vp tap --label Allow --element-type Button` (Turkish: `İzin Ver`). The step `Your First Cat` at `75%` shows.
- **First cat.** `vp shot first-cat-empty`; `onboarding.firstCat.continueButton` is `[disabled]`.
  `vp tap --id catForm.nameField`, then `axe type 'Miso' --udid $UDID`. `catForm.nameField` has value
  `Miso` and Continue is enabled (the keyboard moves it up to about y=385). `vp shot first-cat-filled`,
  then `vp tap --id onboarding.firstCat.continueButton`.
- **Starter tasks.** The heading reads `What care does Miso need?`. `vp shot task-setup-empty`, then
  `vp tap --id onboarding.taskDemo.feeding` and `vp tap --id onboarding.taskDemo.water`. A ticked row
  leaves the list, so only `onboarding.taskDemo.litterBox` stays. `vp shot task-setup-ticked` and
  `vp tree task-setup-ticked`.
- **Finish.** `vp tap --id onboarding.taskSetup.continueButton`. The tree holds `home.view`, and the
  `home.currentTasks.section` lists `home.currentTask.Daily Feeding` and `home.currentTask.Refresh Water`,
  each with `Miso`, `Today` and `No completions yet`. `vp shot home-after-onboarding`, `vp tree home-after-onboarding`.
- **Second view.** `vp tap --label Tasks --element-type RadioButton`. The tree holds
  `taskManagement.view` and the rows `taskRow.complete.Daily Feeding` and
  `taskRow.complete.Refresh Water`, both with value `Pending`. `vp shot tasks-after-onboarding`,
  `vp tree tasks-after-onboarding`.
- **Side effect: reminders.** `vp reminders "Daily Feeding" "Refresh Water" "Litter Box"`. It copies the
  device's pending notification store into the evidence and counts the titles. Proof: both ticked titles
  have a count above 0 (30 each, 60 in all, on 2026-10-14: the app's 60-reminder cap split across two daily tasks),
  and `Litter Box` has 0.
- **Record.** `echo "feature=onboarding entry=first-launch result=pass" >> <evidence>/run.txt`.

## Gotchas

- The first tap right after a screen change can be lost while the transition animates (seen twice on
  2026-10-14, once with the default tap style and once with the physical style). `vp tap` taps once
  more when the tree did not change; a raw `axe tap` does not.
- Do not tap a starter row twice: a second tap on the next row that slid up ticks a task you did not mean.
  Read `vp ui` between the two row taps if a `vp tap` retried.
- The Simulator app need not be open: on 2026-10-14 axe read the full tree with no Simulator process
  (Xcode 27 ships no `Simulator.app` under `Contents/Developer/Applications` on this Mac). If `vp doctor`
  warns about an empty tree, call xcodebuildmcp `open_sim` and retry.
- The Cat's Name field shows the placeholder `Fluffy` (`Kedoli`) as its value while empty; do not read
  it as typed text.
- "Add Photo" (`catForm.photoMenu`) opens the system photo picker out of process; axe sees none of its
  cells. Leave the photo empty and say so.
- With a tr device, the welcome progress value reads `%25`, not `25%`.
