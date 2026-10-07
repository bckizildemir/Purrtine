# Swift skill recheck — closing summary of the five-file pass

**Written:** 2026-08-14 · **Branch:** `worktree-fix-taskaddview-review` · **Effort:** medium throughout

This closes the pass that `docs/swift-skill-recheck-handoff.md` opened. Five files, one review each,
report-then-fix in the same session. Every pass ran against `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and
`SWIFT_VERSION = 5.0`, so iOS 26 APIs were recorded as gaps, never proposed as fixes.

> **Correction, 2026-09-08.** This pass treated `SWIFT_VERSION = 5.0` as a bar on Swift 6.2 syntax as
> well as on iOS 26 APIs. That was wrong, and item 6 below carries the detail. `SWIFT_VERSION` sets
> the language mode; the host toolchain is Swift 6.4, so `@concurrent` and `nonisolated(nonsending)`
> compile here today. Only the 18.4 deployment target limits availability. Measured evidence:
> `docs/swift6-concurrency-assessment.md`.

The per-file handoffs stay on the branch and hold the evidence. This document holds the outcome.

The real base of this branch is the merge-base with `origin/main`, commit `3be1f0f`. File 1's own fix,
`ccab9fb`, sits inside the reviewed range on this branch — it is not already on `origin/main`. A
reader who trusted the old table below would have treated the largest change in the diff (roughly
1200 changed lines across 24 new files) as already merged upstream.

| # | File (under `CatCareCalendar/`) | Skills | Commit |
| --- | --- | --- | --- |
| 1 | `Views/Tasks/TaskAddView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | `ccab9fb` |
| 2 | `Models/CareTask.swift` | `swiftdata-pro` | `4ec597f` |
| 3 | `Models/TaskAssistantViewModel.swift` | `swiftdata-pro`, `swift-concurrency-pro` | `2a88736` |
| 4 | `Utilities/NotificationManager.swift` | `swift-concurrency-pro` | `b44961f` |
| 5 | `Views/Tasks/TaskEditView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | `8de699c` |

> ~~**One document is still missing from this branch.**~~ **Closed 2026-09-08.**
> `docs/swift-skill-recheck-handoff.md` and the **Swift review skills** route table in `CLAUDE.md`
> both reached `main`. All five recheck documents and the routing table are on `main` today. The
> paragraph that used to sit here described branch `fix/remove-orphan-cats-selection-done` in
> August 2026 and no longer describes anything.

## What each file found and what was fixed

### File 1 — `TaskAddView.swift`

The view was 1328 lines. `ccab9fb` cut it to 651. The pass extracted ten section views, seven feeding
views, and `FeedingFieldSupport` (the portion encode, decode and display rules), and it replaced the
`try?` around notification scheduling with a `CancellationError` filter plus a logged `catch`. The
save-failure path gained the `.errorDataSave` alert and an error haptic.

The count moved again after the review fixes below: it is 622 lines now. Do not treat either number
as fixed — measure the file again before you quote a line count.

Left behind, and picked up later in the pass: the hand-rolled `NotificationScheduleInfo` projection
(fixed in file 5), and `colorForCategory` (still open).

### File 2 — `CareTask.swift`

Fixed: the `schedules` and `completions` relationships had no declared inverses, so SwiftData had to
infer them. `4ec597f` declares them explicitly.

Checked and rejected: CloudKit rules do not apply here — no `cloudKitDatabase` argument, no
entitlements file, no source reference. `Set<Cat>` of `@Model` objects in the two task forms is safe
across a save. Adding a SwiftUI `Color` to `CareTaskCategory` was left alone; see the open gaps.

### File 3 — `TaskAssistantViewModel.swift`

Four findings, all fixed in `2a88736`.

1. **High — SwiftData models crossed an actor boundary.** `TaskAssistantCloudInterpreting` was a
   plain `Sendable` protocol, so the Firebase interpreter read `CareTask` properties off the main
   actor. It is now `@MainActor`.
2. **Fire-and-forget scheduling** that hand-rolled the projection and swallowed errors — replaced by
   an injected `TaskNotificationScheduling` and an awaited call.
3. **Main-actor blocking on photo save** — `savePhotosToDocuments` is now `nonisolated static`,
   called through `Task.detached(priority: .userInitiated)`.
4. **A deliberate stop reported a dictation failure** — the `onFailure` callback now guards on
   `isRecording`.

Reported, not fixed: the view model holds strong references to `@Model` objects across suspension
points. No reachable failure today, because the chat hides the tab bar and `endChat` clears the
session.

### File 4 — `NotificationManager.swift`

One finding fixed in `b44961f`, three reported.

1. **High — cancellation was never checked, so every cancel of the scheduling path was inert.** The
   `catch is CancellationError` handlers in three other files were dead code. `try
   Task.checkCancellation()` now guards the schedule loop and the per-date add loop. The checks are
   **deliberately absent from the cancel loop**: abandoning a cancel pass leaves reminders that still
   fire, while abandoning an add pass is safe because the next resync rebuilds from the store. That
   asymmetry is load-bearing.

Reported, not fixed: the cancel-then-add span lets two concurrent callers interleave and lose a
task's earliest reminder; `applySettings` fires a handle-less badge sync; and the
`@preconcurrency UNUserNotificationCenterDelegate` conformance is a dynamic precondition rather than
a static guarantee. See the open gaps.

### File 5 — `TaskEditView.swift`

Fixed in `8de699c`:

- **High — a failed save told the user nothing.** `updateTask` throws on a blank title; the `catch`
  only printed. The Save button looked dead. It now raises the same alert and haptic as file 1.
- **High — `try?` swallowed every notification error**, including the `CancellationError` that file 4
  had just made reachable, and including a failed cancel that leaves reminders firing. `8de699c` made
  file 5 read the model before the hop rather than inside a closure that runs after `dismiss()`. At
  that point file 1 did **not** do the same: `TaskAddView` still read `task.title` inside the
  post-`dismiss()` catch. `38a6bc1`, one of the four review-fix commits below, hoisted that read in
  file 1 too. Only after `38a6bc1` do both twins share the same shape.
- **Medium — `onAppear` could re-populate the form**, overwriting the user's edits and resetting the
  baseline that `hasUnsavedChanges` compares against. Guarded on `initialSnapshot == nil`.
- **Medium — the last hand-rolled `NotificationScheduleInfo` projection.** Now `activeInfos(for:)`.
  `TaskAddView` held the same copy and was fixed in the same commit; the file-4 handoff's claim that
  file 1 had already fixed it was wrong.
- **Low — housekeeping the twin view already had:** `Theme` colors instead of raw `UIColor`,
  `clipShape(.rect(cornerRadius:))` instead of the deprecated `cornerRadius()`, `focusedField = nil`
  instead of the `UIApplication.sendAction` responder hack, and removal of a stray `Color` scroll
  child plus a `scrollContentBackground(.hidden)` applied to a `VStack`, where it does nothing.

`ios-navigation-chrome` produced nothing actionable for either view. `ToolbarItem(placement: .title)`,
`ToolbarSpacer` and `.toolbarRole(.editor)` are all iOS 26. `Views/Components/SheetToolbarButtons.swift`
is already the centralized backport the skill asks for, and both sheets use it.

## Reported and deliberately not fixed

| # | Where | Why it was left |
| --- | --- | --- |
| 1 | The Date toggle in `TaskEditView` is not persisted | `saveChanges` always passes `scheduledDate`, whatever `hasDate` says. Turn Date off, save, reopen: it is back on, and reminders keep firing on the old date. Honouring "no date" means deactivating or deleting the schedule — a `TaskFormPersistence` and notification change with no test coverage, and a product decision. |
| 2 | `NotificationManager.shared` reached directly from both task forms | No test can observe what a view schedules. Injecting into one twin only would add an unused seam and deepen the drift between them. Fix both together, with a test that consumes the seam. |
| 3 | `scheduleCareTaskNotifications` interleaves with `scheduleResync` | A task can silently lose its earliest reminder. Every cheap serialization deadlocks, because the method calls `cancelCareTaskNotifications` internally. `InFlightMainActorOperation` looks like the seam but *coalesces* callers, which would drop one of two schedule calls with different `infos`. |
| 4 | Eight `some View` computed properties in `TaskEditView` | File 1's extracted sections take different bindings, so this is a rewrite rather than a reuse. |
| 5 | `colorForCategory`, four copies | `CareTaskCategory.color` exists but returns a `String`, and it disagrees with the view switch (`vet`: `systemPurple` vs `.orange`; `grooming`: `systemturquoise` — itself a broken name — vs `.cyan`). Reconciling needs a colour decision across four views. |
| 6 | `applySettings` fires a handle-less badge sync | Benign: the `badgeSyncToken` guard makes the last writer win, and `NotificationManagerBadgeTests` covers it. Making it awaitable is a view-level change. |
| 7 | `@preconcurrency UNUserNotificationCenterDelegate` | The iOS 18.4 SDK header carries no `NS_SWIFT_UI_ACTOR`, so main-actor isolation is a dynamic precondition. An off-main callback traps rather than races. Every alternative keeps the same assumption or delays `completionHandler`. |
| 8 | `TaskAssistantViewModel` holds `@Model` references across suspension points | No reachable failure today. Re-check if the assistant ever gains a path to the My Cats tab without ending the chat. |
| 9 | Batching the per-task cancel pass into one `pendingNotificationRequests()` fetch | Latency, not correctness, and `NotificationManagerSchedulingTests` asserts the exact call grouping. Pick it up with item 3, where the suspension points shrink anyway. |
| 10 | A task group for the cancel and schedule loops | Rejected outright. The cancel pass must precede the add pass, the client is `@MainActor` so a group buys only overlapped XPC latency, and it would destroy the deterministic ordering the tests assert. |

## Open gaps

Re-checked after the four review-fix commits below. Each item states its current status.

**Found during the pass, outside every reviewed file:**

1. **Still open — this is the gap that matters most.** Feeding details entered in the Add sheet are
   never saved. `TaskAddView.customFieldValues` still only feeds the unsaved-changes snapshot and the
   feeding sheet's own display; nothing writes it to `CareTask` or `TaskFormDraft`. `CareTask.swift`
   still has no custom-field storage. Confirmed again on the current `HEAD`. Fixing it needs a model
   change, a migration, and a product decision about editing feeding details after creation.

**Test coverage:**

2. **Closed by `6ce4dc7`.** `FeedingFieldSupportTests.swift` now covers `FeedingFieldSupport` with 13
   tests. Given gap 1, those rules still protect data that is never persisted, but the coverage gap
   itself is closed.
3. **Still open.** Nothing covers file 4's cancellation checks. No test file references
   `checkCancellation` or filters `CancellationError`, so the checks that make `scheduleResync`
   responsive are still unverified.
4. **Still open.** `NotificationSchedulerSpy` can be injected into `TaskAssistantViewModel` (file 3's
   fix), but no test does it, so nothing asserts what `confirmTaskCreation` schedules.
5. **Still open.** No test observes what either task form schedules. Both `TaskAddView` and
   `TaskEditView` still call `NotificationManager.shared` directly (item 2 above).

**Version gaps recorded:**

6. **`@concurrent`** is the Swift 6.2 answer for file 3's photo-save offload. `Task.detached` is the
   sanctioned fallback (`swift-concurrency-pro/bug-patterns.md`) and is what ships.
   **Correction, 2026-09-08:** this item was filed as "not actionable at 18.4 / Swift 5.0". That
   framing was wrong. `SWIFT_VERSION = 5.0` selects the language mode, not the accepted syntax, and
   `@concurrent` compiles on this toolchain (Swift 6.4) at iOS 18.4. It is available now, so item 6
   is an open cleanup rather than a blocked one. Item 7 below is a real availability gap; this one
   never was. See `docs/swift6-concurrency-assessment.md`.
7. **The iOS 26 navigation chrome** — `ToolbarItem(placement: .title)`, `ToolbarSpacer`,
   `.toolbarRole(.editor)` — stays unavailable. `SheetToolbarButtons` already gates `Button(role: .close)`
   behind `#available(iOS 26.0, *)`; extend that file rather than adding per-screen checks.

## Verification

Every commit in the **five-file pass** was verified the same way, on iPhone 12 / iOS 26.5
(`4AD389C4-F709-4D96-8F4D-E497AD3C2E67`), one simulator at a time:

```text
session_set_defaults({ projectPath, scheme: "CatCareCalendar", simulatorId, bundleId })
build_sim({})                                              // ~25s
test_sim({ extraArgs: ["-only-testing:CatCareCalendarTests"] })   // ~60s
```

**283 unit tests passed, 0 failed, at every step of the five-file pass, including after file 5.**
This claim covers the five-file pass only. It does **not** extend to the branch-review fix commits
below — see "Verification of the fix commits". No test was changed and
no test was added across the whole pass — every fix was either behaviour-preserving or covered a path
no test reached. `CatCareCalendarUITests` exercises `TaskEditView` (`taskEdit.titleField`,
`taskEdit.saveButton`, `taskEdit.caregiverButton`) and was **not** run for file 5; the CI-parity dual
destination run stays on the `xcodebuild` CLI with `-disable-concurrent-destination-testing`.

## Notes on the skill setup

Unchanged across all five files. The hook in `.claude/settings.local.json` (matcher
`Edit|MultiEdit|Write`) only reminds; it does not enforce. Dedupe is per session and substring-based.
Subagent behavior is still unverified.

It also names a skill by file type rather than by the routing table: editing a two-line `catch` in
`BulkTaskEditService.swift` produced a reminder to run `swiftdata-pro` over it. The routing table was
the authority for this pass, so those reminders were recorded and not followed.

## Branch review and its fix commits

A separate two-axis review (Standards, Spec) ran over this branch after the five-file pass closed. It
produced four fix commits, all on `worktree-fix-taskaddview-review`. Two later commits — `86fcd68`
and the standards/spec remediation described below — followed from two further review rounds.

### `38a6bc1` — correctness and spec fixes

- `TaskAddView` read `task.title` inside the `catch` of a `Task` that runs after `dismiss()` — a
  `@Model` access on a view that is already gone. The title is now hoisted with `infos`, matching
  `TaskEditView`. This is the fix referenced above, under file 5's entry.
- `TaskEditView` logged a failed notification cancel with `print()` alone. `cancelNotificationsForTask`
  now owns the dismiss, so the sheet stays on screen to raise an alert on failure. The new
  localization key `error.reminder_cancel` keeps that alert honest: the data save succeeded and only
  the cancel failed, so reusing `error.data_save` would have misstated the failure.
- `TaskAssistantViewModel.scheduleNotifications` guarded `infos.isEmpty == false` at
  `TaskAssistantViewModel.swift:410`, where the two task forms did not. The guard was removed rather
  than copied into the two forms: `scheduleCareTaskNotifications` already treats an empty array as a
  no-op in both of its loops, so the rule belongs in `NotificationManager`, not at three call sites.
- Five spec findings went into this commit; one did not survive verification. The review had claimed
  `TaskAddView`'s keyboard Done button lacked the `.bold()` weight that `TaskEditView` had. It did
  not — `ccab9fb` had already moved both to `.bold()` — so no edit was made for that finding.

### `d6b547f` — standards fixes

Added a `#Preview` to every new view file under `Views/Tasks/` from this branch. Replaced two raw
colors with theme tokens: `Theme.accent` for the food-option selection checkmark, and a new
`Theme.success` token for the feeding field status icon. Gave `FeedingDetailsSheet` the same
`Theme.background` every sibling task surface uses, for a consistent sheet background.

### `6ce4dc7` — design-smell fixes

Deduplicated the date label used by `TaskAddDateSection` and `TaskEditView`. (Correction: this
commit did not actually *extract* anything. It left the rule as a `static func label(for:)` on
`TaskAddDateSection`, so the edit sheet depended on a sibling feature's view type. The real
extraction — `Date.taskDayLabel` in `Utilities/TaskDateLabel.swift` — landed in the later
standards/spec remediation commit.) Collapsed the ten flat
feeding states into one `FeedingDetailsDraft` type. Merged `FeedingDetailsField` into `TaskAddField`.
Replaced `FeedingFieldSupport`'s string-sentinel and suffix matching with a typed `FeedingFieldKind`
enum. Unified the three sibling section views — priority, category, frequency — onto one
let-plus-`onSelect` contract. Added `FeedingFieldSupportTests`, closing open gap 2 above.

### Test count

The unit test suite grew from 283 (the count recorded throughout the five-file pass and the
`38a6bc1`/`d6b547f` commit messages) to **296** tests. The 13 added by `FeedingFieldSupportTests` in
`6ce4dc7` account for the difference.

### Verification of the fix commits

**Correction.** An earlier version of this document stated that every commit was verified with
`build_sim` and `test_sim`, and reported the 296 figure as "verified by counting `@Test` attributes".
Both statements were wrong for `6ce4dc7`, the widest refactor in the range: no build or test run was
recorded for it, and a static count of `@Test` attributes is not a test run. The claim has been
removed rather than restated.

The suite was run for real on the standards/spec remediation commit that follows `86fcd68`:

```text
xcodebuild -scheme CatCareCalendar \
  -destination 'platform=iOS Simulator,name=iPhone 12,OS=18.5' \
  -only-testing:CatCareCalendarTests test
```

- App target build: **BUILD SUCCEEDED** (compile-only, generic iOS Simulator destination).
- Unit tests: **296 tests in 41 suites passed, 0 failed, 0 skipped** — `TEST SUCCEEDED`.

`CatCareCalendarUITests` was still not run; the CI-parity dual-destination run stays on the
`xcodebuild` CLI with `-disable-concurrent-destination-testing`.
