# Purrtine verification map

This directory is the maintained source for verifying what a user of Purrtine sees. Read
this index before you drive the app, then use the matching feature file as the recipe. The harness
is `scripts/vp.sh` plus `axe` (or xcodebuildmcp UI tools) on the run's own fresh simulator; see
`../SKILL.md` for launch, doctor and cleanup.

## Baseline preconditions

- A run is open: `vp.sh start` → `vp.sh build` → `vp.sh install` → `vp.sh launch`, and `vp.sh doctor`
  exits 0. Every command below runs from the repo root; `vp` means
  `.claude/skills/verify-purrtine/scripts/vp.sh`.
- `UDID` is the run's device: `UDID=$(cat /tmp/verify-purrtine.lock/udid)`.
- Two runs at once (an English and a Turkish pass): give each its own lock folder and use the same prefix on
  every `vp` call of that run: `export VP_LOCK_DIR=/tmp/verify-purrtine-en.lock` (and `-tr.lock`). At most
  `SLIM_SIM_MAX` (2) verify clones exist on the Mac; a third `start` waits for a slot. Without the override,
  a second `start` waits silently for the first run's lock (up to 3600 s); `vp status` or
  `$VP_LOCK_DIR/owner` shows who holds it. Replace `/tmp/verify-purrtine.lock` in every path of these recipes
  with your `$VP_LOCK_DIR`.
- The app was launched with no arguments. A fresh device has no data, so the app opens on the
  onboarding. Every other feature needs [Onboarding](./onboarding.md) done first, with a cat and
  its starter tasks — data comes only from user screens, never from More → Developer Tools.
- The Simulator app need not be open: axe reads the tree without it, and `open -a Simulator` fails
  on this Mac. If `vp doctor` reports an empty tree, call xcodebuildmcp `open_sim`.

## Driving conventions

- Tap with `vp tap <axe selector>`: it uses `axe tap --tap-style physical --wait-timeout 10`, waits up
  to 8 s for the screen to change, and taps once more when it did not (a tap during a transition can be
  lost). It exits 1 when the screen still did not change; then read `vp ui`.
- A tap that saves, completes, or toggles something uses `vp tap --once …`: no second tap, because a
  slow save that shows after 8 s plus a second tap would save twice or untick the row. The recipes mark
  these taps. On a `--once` WARN, read `vp ui` before you tap again.
- Match by accessibility identifier (`vp tap --id …`) first, by label (`--label`) second, and narrow a
  label with `--element-type`. Coordinates (`axe tap -x … -y … --udid $UDID`) only when an element has
  neither.
- Tab bar items are `RadioButton` elements with SF Symbol ids: `vp tap --label Tasks --element-type RadioButton`.
  Labels: Home | Ana Sayfa, Tasks | Görevler, Whiskers | Whiskers, More | Daha Fazla.
- After each action, read `vp ui` and check the expected element before the next action.
- Type with `axe type 'text' --udid $UDID` after a tap on the field puts the focus there. Type real
  dictionary words: the keyboard's autocorrect can change a made-up word on save (see add-cat.md).
- `vp tap --id X` fails when two elements share the id (for example `taskAssistant.input`, the consent
  buttons): add `--element-type`, or use the label.
- `vp tap` can report "screen changed" for a tap that did nothing (keyboard, checkboxes, Routine Status
  rows). Read the value or the screen yourself after every such tap.
- `axe type` goes through the device keyboard, so typed text is auto-capitalised and, on a Turkish device,
  `i` becomes `ı` ("Milo" saved as "Mılo"). Avoid `i` in typed text in a Turkish pass ("Luna" is fine).
- A tab keeps its navigation stack. Before you tap a shortcut on a tab you used earlier, check `vp ui`
  and tap `BackButton` until the tab's root shows.

## Running a feature in Turkish

The app follows the device language; there is no app flag for it. Start the run with
`vp start --lang tr`: it sets the fresh device's system language to Turkish (`tr-TR`, locale
`tr_TR`) and reboots it before the app is installed. Every feature file gives the labels as
`English | Türkçe`; identifiers (`--id`) do not change with the language, so prefer them. Run every
feature of a pass in one language on one device; a language change on a running device needs a reboot.

## Proof and skip reporting

- Capture the action and the resulting state: `vp shot <name>` before and after the step that
  matters, and `vp tree <name>` for the state you assert on.
- A save is proved from a second view (the list, Home, History), not from the closing sheet.
- Record the feature file and entry point you used with the evidence (a line in `run.txt` in the
  evidence folder is enough: `echo "feature=onboarding entry=first-launch" >> <evidence>/run.txt`).
- Report an entry point you could not reach with the command you tried and the precondition that was
  missing. Do not report it as verified through a different path.
- The system photo picker runs out of process and axe cannot read its cells. A real pick is driven by
  [Cat photo](./cat-photo.md): pictures added with `simctl addmedia`, the cell found in a `vp shot`
  screenshot and tapped by coordinates. A run that skips that recipe reports the photo pick as not
  checked. (`-inject-test-photo`, #52, is for the UI-test harness only; this skill never launches with flags.)

## Feature entry contract

Each feature file starts with an H1 title and one paragraph that describes the user-visible
behavior, then exactly four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`,
`Driving it with axe`, `Gotchas`.

## Features

- [Onboarding](./onboarding.md) — first launch: welcome, notification permission, first cat, starter
  tasks, landing on Home. Proved 2026-10-14.
- [Add a cat](./add-cat.md) — a second cat from Home "+" or More → My Cats. Proved 2026-10-14.
- [Add a task](./add-task.md) — a custom daily task from the Tasks tab "+" menu, with reminders. Proved 2026-10-14.
- [Complete a task](./complete-task.md) — tick a task in the Tasks list and see it in History and Home. Proved 2026-10-14.

- [Whiskers](./whiskers.md) — the task assistant: on-device request, cloud consent sheet, decline and
  accept, the Settings toggle, one capped cloud request. Not yet proved (written from source 2026-11-07).
- [Reminder nudge](./reminder-nudge.md) — the "open the app" nudge notification (PR #100: one-hour floor,
  horizon cut), read with `vp reminders`. Not yet proved (written from source 2026-11-07).
- [Notification tap](./notification-tap.md) — tapping a delivered reminder opens that task's Edit sheet.
  Not yet proved (written from source 2026-11-07).
- [Settings](./settings.md) — More → Settings and Support: display, Whiskers toggle, Rate App, Privacy,
  Terms, Feedback links. Not yet proved (written from source 2026-11-07).
- [History](./history.md) — completed tasks, search, per-task scope, empty states. Not yet proved
  (written from source 2026-11-07).
- [Cat photo](./cat-photo.md) — add, change and remove a cat's photo with the real system photo picker.
  Not yet proved (written from source 2026-11-07).

Home order (PR #105): Routine Status comes first, then Today & Overdue, then Quick Actions. Recipes that
look for a task under "Today & Overdue" or Routine Status must not assume the old order.

A maintenance pass drives all of them on one device, onboarding first, then in this order: add-cat,
add-task, complete-task, history, whiskers, reminder-nudge, notification-tap, settings, cat-photo. The
Whiskers cloud step needs the owner's yes (see `whiskers.md`) and at most 10 cloud requests per pass.
The four proved recipes: last full pass 2026-10-14, second pass, every recipe as written; evidence
`~/verify-evidence/purrtine/2026-10-14-233836-4c55/`.

## Turkish pass

A full pass runs again in Turkish on a new device: `vp start --lang tr`, then build, install, launch and
`vp doctor` (it prints the device language `tr-TR`). One language per device, so this is a second run with
its own evidence folder. The recipes' `English | Türkçe` labels and the `--id` selectors carry over;
task titles in selectors change (`taskRow.complete.Günlük Besleme`). Recipes that must run in Turkish, at
the least:

- [Onboarding](./onboarding.md): welcome, notification alert (`İzin Ver`), cat step, starter tasks (titles
  Günlük Besleme, Su Tazeleme, Kum Kabı Temizliği).
- [Whiskers](./whiskers.md): the consent sheet text (long Turkish message, scroll and detents), the
  Turkish buttons `İzin Verme` and `İzin Ver`, a Turkish request such as `Su Tazeleme tamamla`.
- [Settings](./settings.md): every label, the Support footer, the About card.
- [Reminder nudge](./reminder-nudge.md): the notification texts "Hatırlatmalar azalıyor" and the body.
- [Notification tap](./notification-tap.md): the banner text in Turkish.
- [History](./history.md): the search field (placeholder "Search history | Geçmişte ara") and the scoped header text.

Turkish text is now the informal "sen" form everywhere (PR #107): "Kedini tanıyalım", "İlk Kedin",
"Hoş Geldin", "Bakıcıları yönet". Old "siz" strings ("Kedinizi", "istediğiniz") in a screenshot mean the
build is older than #107. Typed Turkish text: see the `i` note under Driving conventions. A Turkish pass found
no cut-off text, no raw keys and Turkish date formats ("7 Kas 2026") on 2026-11-07.

The other recipes follow when time allows; a Turkish pass of add-cat, add-task and complete-task already
passed in part on 2026-10-14 (welcome screen only). Cloud requests of a Turkish pass count against the
same 10-request budget only if the pass runs in the same session; a separate pass has its own budget, and
the owner's yes is needed again.
