# CatCareCalendar verification map

This directory is the maintained source for verifying what a user of CatCareCalendar sees. Read
this index before you drive the app, then use the matching feature file as the recipe. The harness
is `scripts/vp.sh` plus `axe` (or xcodebuildmcp UI tools) on the run's own fresh simulator; see
`../SKILL.md` for launch, doctor and cleanup.

## Baseline preconditions

- A run is open: `vp.sh start` → `vp.sh build` → `vp.sh hold` → `vp.sh install` → `vp.sh launch`, and `vp.sh doctor`
  exits 0. Every command below runs from the repo root; `vp` means
  `.claude/skills/verify-purrtine/scripts/vp.sh`.
- `UDID` is the run's device: `UDID=$(cat /tmp/verify-purrtine.lock/udid)`.
- The app was launched with no arguments. A fresh device has no data, so the app opens on the
  onboarding. Every other feature needs [Onboarding](./onboarding.md) done first, with a cat and
  its starter tasks — data comes only from user screens, never from More → Developer Tools.
- The Simulator app need not be open: axe reads the tree without it, and `open -a Simulator` fails
  on this Mac. If `vp doctor` reports an empty tree, call xcodebuildmcp `open_sim`.

## Driving conventions

- Tap with `vp tap <axe selector>`: it uses `axe tap --tap-style physical --wait-timeout 10` and taps
  once more when the screen did not change (a tap during a transition can be lost). It exits 1 when the
  screen still did not change; then read `vp ui`.
- Match by accessibility identifier (`vp tap --id …`) first, by label (`--label`) second, and narrow a
  label with `--element-type`. Coordinates (`axe tap -x … -y … --udid $UDID`) only when an element has
  neither.
- Tab bar items are `RadioButton` elements with SF Symbol ids: `vp tap --label Tasks --element-type RadioButton`.
  Labels: Home | Ana Sayfa, Tasks | Görevler, Whiskers | Whiskers, More | Daha Fazla.
- After each action, read `vp ui` and check the expected element before the next action.
- Type with `axe type 'text' --udid $UDID` after a tap on the field puts the focus there. Type real
  dictionary words: the keyboard's autocorrect can change a made-up word on save (see add-cat.md).
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
- The system photo picker runs out of process. A step that needs a picked photo is not verified;
  say so.

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

A maintenance pass drives all four in this order on one device: onboarding, add-cat, add-task,
complete-task (last full pass: 2026-10-14, second pass, every recipe as written; evidence
`~/verify-evidence/purrtine/2026-10-14-233836-4c55/`).
