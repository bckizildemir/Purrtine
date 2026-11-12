# History

History lists every completed task occurrence, newest first, with the task title, date, time and cats. A
user can search it, and open it scoped to one task from Home → Routine Status. It has no filters, no
grouping and no undo. Not yet proved (written from source 2026-11-07); the completion-to-History path was
proved 2026-10-14 inside `complete-task.md`.

## Sub-features

- `history-list` rows `history.row.<task title>`: icon (green on time, orange late), title, date, time, cats.
- `history-empty` three empty states: no tasks (`history.state.noTasks`, button
  `history.createFirstTaskButton`), tasks but no completions (`history.state.noCompletions`, "No
  statistics yet | Henüz istatistik yok"), a scoped task without completions (`history.state.taskNoCompletions`).
- `history-search` the search field filters by task title, cat name or notes; no match shows
  `history.state.searchEmpty` ("No Tasks Found | Görev Bulunamadı").
- `history-scope` Home → Routine Status row opens History for that task: a header with the title,
  "N completions | N tamamlanma" and "Show All | Tümünü Göster".
- Deleting a task removes its completions: `CareTask.completions` has `deleteRule: .cascade` (`Models/CareTask.swift:20`), so a History row of a deleted task cannot exist and the `unknown` id fallback (`HistoryView.swift:252`) is unreachable. Measured 2026-11-12: after deleting Brush coat in Tasks (left swipe, `taskRow.delete.Brush coat`, no confirm) the More History card went from 3 to 2.
- There is no undo: a completion is removed only by deleting the task (the writer's "undo" is an internal
  rollback for failed saves).

## How to get to it (user POV)

- More | Daha Fazla tab → the History card (`settings.shortcut.history`, its value is this week's count).
- Home tab → "Routine Status" section → a task row (`home.routineStatus.row.<title>`): History scoped to
  that task.

## Driving it with axe

Preconditions:

- Onboarding is done. For the empty state, nothing completed yet. For the list, complete "Daily Feeding"
  from the Tasks tab (`complete-task.md`), and complete "Refresh Water" too for the search and scope
  steps. Data only from user screens.

Steps:

- **Empty state first.** Before any completion: More → `settings.shortcut.history`. The tree holds
  `history.view` and the text "No statistics yet" (`history.state.noCompletions` and the other state ids do
  not exist on the device); the card value on More reads 0. `vp shot history-empty`.
  (A device with no task at all shows `history.state.noTasks`; a fresh run cannot be in that state after
  onboarding with starter tasks.)
- **Complete.** Per `complete-task.md`: Tasks tab, `vp tap --once --id 'taskRow.complete.Daily Feeding'`,
  then the same for `Refresh Water`.
- **List.** More tab (`BackButton` first if needed), `vp tap --id settings.shortcut.history`. The tree
  holds `history.row.Daily Feeding` and `history.row.Refresh Water`; the one completed last is first
  (compare their frames' y). Each row reads title, today's date, the time and `Miso`. The More card now
  reads 2. `vp shot history-list`, `vp tree history-list`.
- **Search.** The search field is hidden until you pull the list down (`axe swipe --start-x 195 --start-y 300
  --end-x 195 --end-y 600`). It has the placeholder "Search history | Geçmişte ara" (PR #107; before it had
  none). axe reads it as a TextField with no label whose value is the placeholder, so
  `--label Search --element-type SearchField` finds nothing: tap it by coordinates (about `axe tap -x 195 -y 123`),
  then `axe type 'Water' --udid $UDID`: only `history.row.Refresh Water` stays. Type a word that matches
  nothing (`zzz`): `history.state.searchEmpty` shows. Search by cat name (`Miso`): both rows return. Clear
  with the button "Clear text" (`axe key 42`, backspace, did not delete). Do not tap the keyboard's emoji key.
- **Scope.** Home tab, `vp tap --id 'home.routineStatus.row.Daily Feeding'` (a tap by id or on the row's centre did
  nothing; a coordinate tap at the left of the row, x=90 and the row's y from `vp ui`, opened it). History opens on the More tab
  scoped: header text `Daily Feeding`, `1 completions | 1 tamamlanma` (the string has no singular form), the button "Show All". Only `history.row.Daily Feeding` shows.
  `vp tap --label "Show All"`: both rows show. `vp shot history-scoped`, `vp tree history-scoped`.
  A scoped task without completions shows `history.state.taskNoCompletions` ("No completions for this
  task | Bu görev için henüz tamamlama yok").
- **Second view of a completion.** Home → Routine Status row reads `…, Last done today, Due tomorrow`
  (see `complete-task.md`).
- **Record.** `echo "feature=history entry=more-history result=pass" >> <evidence>/run.txt`.

## Gotchas

- The tab keeps its stack: after this recipe, More still shows History. Tap `BackButton` before other More
  shortcuts.
- Rows have no cat-filter, date-filter or grouping: do not look for chips. The old statistics source
  strings (`history.this_week`, `history.filters`, …) are not used by this screen.
- A task completed several times shows several rows with the same identifier `history.row.<title>`; count
  rows by frame, not by id.
- The scope survives until "Show All" is tapped; opening History from the More card resets it.
- Measured 2026-11-07: `history.row.<title>` is set on every text of a row, not on one element. The Today list
  in Tasks orders the newest-created task first (Brush coat above Daily Feeding): read row positions from
  `vp ui` each time.
- Since PR #106 (schema V2) a History row keeps its cat even when the cat's task is gone; before it, a row could
  show no cat. A run on a build older than #106 may show a row with no cat.
- Turkish: the search placeholder reads "Geçmişte ara"; on 2026-11-07 the Turkish pass saw the older "Arayın".
- Row icon: the category's icon in green when the completion was on time (green seen 2026-11-12); orange late not reached. `history.createFirstTaskButton` is shown only with no tasks at all: not driven, source only.
