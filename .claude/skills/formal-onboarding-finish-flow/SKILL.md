---
name: formal-onboarding-finish-flow
description: "Model-check Purrtine's first-run flow (Welcome → Notifications → Your first cat → Starter tasks → Home) and its finish step with TLA+: one first cat, the starter tasks saved with it, and hasCompletedOnboarding set only after that save, across double taps, failed saves, retries, Back, permission changes and app kills. Use when a change touches OnboardingTaskSetupModel, OnboardingManager, OnboardingDataBuilder, OnboardingView or its step views, CatFormView's onboarding mode, CareTaskWriting's commit order, or ContentView's onboarding switch."
---

# Formal check: onboarding finish flow

## The promise

**Property.** Onboarding ends with at most one first cat and its starter tasks saved, and
`hasCompletedOnboarding` is set only after that save; a double tap, a failed save, a retry, Back, a
permission change, a deep link or an app kill never leaves a saved cat behind an onboarding the
caregiver must walk through again, and never reaches Home with no cat unless the caregiver chose that.

**Harm.** A duplicate first cat (with a second set of starter tasks and reminders), a caregiver stuck
repeating onboarding, or Home with an empty household after a save that did not happen.

## Run it

```sh
TLA2TOOLS=/path/to/tla2tools.jar .claude/skills/formal-onboarding-finish-flow/run.sh [OUT_DIR]
```

- Needs Java 11+ and TLC **1.7.4** (`tla2tools.jar`). `JAVA` may name the java binary. A `tlc`
  command on `PATH` works too. The `/statechart` skill can install TLC on its first run.
- About 1 s, 130 distinct states.
- `run.sh` first reads four guards from the Swift code (below), prints them, writes
  `OUT_DIR/OnboardingFinish.cfg` with them, copies the spec and view there, and runs TLC.
- Exit 0: every rule holds. Exit 12: a rule breaks. Other exit: setup error or TLC error.
- Then read the result with the **`/statechart`** skill on `OUT_DIR/OnboardingFinish.tla`, with the
  config `OUT_DIR/OnboardingFinish.cfg` and the view `OUT_DIR/view.mjs`. It gives each broken rule's
  shortest path as screens and taps, and the first-run chart. Show the chart to the owner as a
  `mermaid` block.

Today's expected result (sync commit below): exit 0, every rule holds. Anything else is new.

## Files

| File | What |
| --- | --- |
| `OnboardingFinish.tla` | The model. Each action names the code it stands for. |
| `view.mjs` | Statechart view: screens as the caregiver sees them, steps in their words. |
| `run.sh` | Reads the guards from the code, writes the cfg, runs TLC. |
| `charts/` | The last `/statechart` output at the sync commit (`chart.mmd`, `report.md`, the cfg). |

## The rules (INVARIANTS)

- `OneFirstCat`: one onboarding run (since the last reset) saves at most one cat.
- `HomeHasCatUnlessChosen`: Home shows a cat unless the caregiver chose to go on without one
  (left the name empty / skipped the cat, or tapped "Continue without saving").
- `NoSavedCatBehindOnboarding`: while onboarding shows and no finish is running, this run has saved
  nothing.
- `TypeOK`, and no deadlock (TLC's default check; `/statechart` reports it as `NoDeadlock`): every
  state has a way on, so the caregiver is never left on a screen with nothing to do.

## Guards read from the code

`run.sh` sets each constant TRUE when its text is in the code, FALSE when it is gone, so the model
checks the code as it is. When one prints FALSE, the model runs the broken variant and the rules
should catch it.

| Constant | Code it reads |
| --- | --- |
| `FinishGuard` | `OnboardingTaskSetupModel.finish()`: `guard isFinishing == false else { return .alreadyFinishing }` |
| `UnstageOnFail` | `OnboardingDataBuilder`: both `unstage(cat, [], …)` (no starter task) and `unstage(cat, tasks, …)` (first commit throws) |
| `FlagOnlyAfterSave` | `finish()`: `completeOnboarding()` appears only in the `else` after `if outcome == .notSaved { … isShowingSaveFailure = true` |
| `LaunchRepair` | `PurrtineApp.init` calls `OnboardingManager.shared.completeIfStoreHoldsCat(in: container.mainContext)`, and that method counts cats with `let catCount = try context.fetchCount(FetchDescriptor<Cat>())` and sets the flag inside `if catCount > 0 {` (#140) |

A refactor that keeps the behaviour but rewords one of these lines prints FALSE and breaks rules:
that is a modelling miss, not a bug. Read the new code, confirm the guard still holds, and update
the text `run.sh` greps for.

## Coverage record

Sync commit: the #140 fix (on top of `922b1cb`, 2026-11-14). Covered code:

- `Purrtine/Models/OnboardingTaskSetupModel.swift`: `finish()`, `retry()`, `continueWithoutSaving()`,
  `saveCatAndTasks()` (catch order), `isFinishing`, `isShowingSaveFailure`, `reminderPrompt`.
- `Purrtine/Utilities/OnboardingDataBuilder.swift`: `createCatAndTasks` (empty-name path, no-task
  path, one commit for cat + tasks), `saveTasks` (index 0 = the commit), `unstage`.
- `Purrtine/Utilities/OnboardingManager.swift`: `hasCompletedOnboarding` (UserDefaults),
  `currentStep`, `tempCatData`, `selectedTasks`, `completeOnboarding()`, `resetOnboarding()`,
  `completeIfStoreHoldsCat(in:)`; `OnboardingStep`.
- `Purrtine/PurrtineApp.swift` `init`: `completeIfStoreHoldsCat` runs once per launch, before the UI.
- `Purrtine/Views/Onboarding/OnboardingView.swift` (step closures, `goBack`, the model built once in
  `onAppear`), `OnboardingTaskSetupStep.swift` (Start, alert buttons), `TaskSetupView.swift` (`tick`,
  Start not disabled while saving), `NotificationPermissionView.swift` (continue after the prompt,
  skip), `OnboardingHeaderView.swift` (Back not disabled while saving).
- `Purrtine/Views/Cat/CatFormView.swift` `.onboarding` mode: `saveCat` writes the name, Skip leaves it.
- `Purrtine/Utilities/CareTaskWriting.swift`: `save` commits first, then awaits the resync.
- `Purrtine/ContentView.swift`: shows `OnboardingView` iff `!hasCompletedOnboarding`; `onOpenURL`.
- `Purrtine/Utilities/NavigationRouter.swift` `handle(_:)` (`.onboarding` route resets the router only).
- `Purrtine/Views/Settings/SettingsDebugViews.swift`: `resetOnboarding()` (DEBUG only).

**Is my change covered?** `git diff 922b1cb -- <the files above>`. If it touches them, re-read the
changed code against the action comments in `OnboardingFinish.tla`, run the check, and compare
with the expected result. Move the sync commit forward (here and in `charts/`) only after you have
confirmed that the model still describes the code at the new commit.

## Fixed finding (#140)

**A kill after the save, before the flag, brought onboarding back over a saved cat; finishing again
saved a second first cat.** Path: Welcome → name the cat → tick a starter task → Start → the first
commit lands → the app is killed before `completeOnboarding()` → relaunch shows Welcome
(`NoSavedCatBehindOnboarding` broke) → finishing again saves a second cat (`OneFirstCat` broke).

Fixed by `LaunchRepair`: at launch a store that holds a cat sets `hasCompletedOnboarding`, so Home
shows. Set `LaunchRepair = FALSE` in a cfg to see the old path again. `storeCat` in the model is the
store's "holds a cat", which survives a kill and a DEBUG reset; `saved` counts this run only.

## Real bug or modelling error?

Replay the `/statechart` path against the code, one step per action, using the action comments in
the spec. A path that needs something the code cannot do (a tap on a hidden button, an `await` the
code does not have, an atomic step the code splits) is a modelling error: fix the spec and say so in
the PR. A path the code can follow is a bug: report it with the path in screens and taps; do not
change the rules.

## What the model leaves out

- How many starter tasks: one boolean "some picked". The cat and all its tasks commit in one save, so
  "tasks without the cat" is not checked separately (it holds by that single commit).
- Reminders themselves: a reminder failure after the commit counts as success
  (`CareTaskRemindersOutOfSyncError` → `.completed`), as in the code.
- The photo: its write failure is logged and the cat saves without it.
- `CancellationError` before the commit: the onboarding `Task` is never cancelled, so not modelled.
- Notification permission (`perm`) only changes the reminder row; the `VIEW FlowView` folds it away.
  Sound because no finish step reads it; if a change makes a finish step depend on permission,
  drop `perm`'s exclusion from `FlowView`.
- A deep link or notification tap during onboarding is modelled as changing nothing in onboarding
  (`ContentView` switches on the flag alone); the router state it leaves for Home is not modelled.
- Bounds: at most 2 finishes running, 2 staged cats, 2 saved cats (`CONSTRAINT Bound`).
- `resetOnboarding()` is DEBUG only; the household stays (`storeCat`), and `saved` counts the new run
  from zero. A kill after a DEBUG reset with cats in the store lands on Home (`LaunchRepair`).
- UserDefaults is treated as written at once (it survives a kill right after the set).

## Chart

`charts/chart.mmd` is the first-run chart. It hides, for readability (TLC still checks them all):
Back on every screen; an app kill on a screen with no save running (it only returns to Welcome with
nothing saved); and a failed save after the caregiver tapped Back during the save (the alert shows
when they return to Starter tasks, the arrow from "Your first cat" to the alert).
