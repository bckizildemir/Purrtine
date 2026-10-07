# Handoff — file 3 of the Swift skill recheck: `Models/TaskAssistantViewModel.swift`

**Written:** 2026-08-14 · **Scope:** one review pass over one file · **Run this at medium effort.**

> **CLOSED — status re-checked 2026-09-08.** The five-file pass finished on 2026-08-14 and every file
> was reviewed and fixed. This document is kept as a record of the brief, not as work to pick up.
> Do not act on the "Your job" and "Not started" rows below: they describe the mid-pass state of
> 2026-08-14. The closing summary is `docs/swift-skill-recheck-summary.md`. Everything under this
> banner is the original brief, corrections marked in place.

## Where this sits

This continues `docs/swift-skill-recheck-file2-handoff.md`, which continues
`docs/swift-skill-recheck-handoff.md`. Read them first. Do not repeat their evidence work.

> ~~**`docs/swift-skill-recheck-handoff.md` is still not on this branch.**~~ **Resolved 2026-09-08.**
> That document and the **Swift review skills** route table in `CLAUDE.md` are both on `main` now.
> Read them from `main`; branch `fix/remove-orphan-cats-selection-done` no longer matters here.

Status of the five files:

| # | File (under `CatCareCalendar/`) | Skills | State |
| --- | --- | --- | --- |
| 1 | `Views/Tasks/TaskAddView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | Reviewed **and fixed** on 2026-08-14 |
| 2 | `Models/CareTask.swift` | `swiftdata-pro` | Reviewed **and fixed** on 2026-08-14 |
| 3 | `Models/TaskAssistantViewModel.swift` | `swiftdata-pro`, `swift-concurrency-pro` | Reviewed **and fixed** on 2026-08-14 |
| 4 | `Utilities/NotificationManager.swift` | `swift-concurrency-pro` | **Your job** |
| 5 | `Views/Tasks/TaskEditView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | Not started |

## Your job

Run **`swift-concurrency-pro`** over `CatCareCalendar/Utilities/NotificationManager.swift`. That is
the only skill the routing table assigns to this file. The routing was verified against these exact
files on 2026-08-14. Trust it; do not re-derive it.

**Report first, then fix.** Files 1 to 3 all ran as report-then-fix, with the user granting the
go-ahead in the same turn. Expect the same.

## Rules for the pass

- **Group findings by severity.** Real problems only. The skill body says "Report only genuine
  problems - do not nitpick or invent issues." Honour that.
- **Reconcile against this repo's reality.** `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and
  `SWIFT_VERSION = 5.0`. A finding that assumes iOS 26 or Swift 6.2 is not actionable here. Flag the
  gap; do not report the iOS 26 API as the fix. **Correction, 2026-09-08:** read `SWIFT_VERSION` as
  the language mode only. Swift 6.2 *syntax* compiles here on the Swift 6.4 toolchain; the 18.4
  deployment target is what limits iOS 26 *APIs*. See the reconciliation notes in `CLAUDE.md`.
- **CloudKit rules do not apply — this is now settled.** File 3 checked it: `AppLaunchBootstrapper`
  builds its `ModelContainer` with no `cloudKitDatabase` argument, there is no `.entitlements` file
  in the repo, and no source file mentions CloudKit. Do not re-derive this.
- **Do not run `ios-memory-perf`.** It is measure-first and symptom-triggered, and it is deliberately
  outside the routing table. Main-actor blocking is still a fair `swift-concurrency-pro` finding —
  its `bug-patterns.md` names it — but do not turn the pass into a perf audit.

## What file 3 found and fixed

Four findings, all applied. Commit: see `git log` for "fix swiftdata/concurrency findings in
TaskAssistantViewModel".

### High

1. **SwiftData models crossed an actor boundary** (`TaskAssistantViewModel.swift:95`).
   `TaskAssistantCloudInterpreting` was a plain `Sendable` protocol, so its `interpret` body ran on
   the cooperative pool under Swift 5 semantics. `FirebaseTaskAssistantCloudInterpreter` then read
   `task.title`, `task.assignedCats` and `task.isOverdue` off the main actor, and built
   `TaskAssistantAction`s holding `CareTask` references there.
   **Fix:** `@MainActor` on the protocol. Only the network call suspends. The
   `init(region:)` had to become `nonisolated`, because Swift evaluates the view model's default
   argument outside the main actor.

### Medium

2. **Fire-and-forget notification scheduling** (`scheduleNotifications(for:)`). It hand-rolled the
   fifteen-field `NotificationScheduleInfo` projection that
   `NotificationScheduleInfo.activeInfos(for:)` already owns, swallowed every error with `try?`
   inside an unstructured `Task {}`, and reached `NotificationManager.shared` directly, so no test
   could observe it.
   **Fix:** an injected `notificationScheduler: any TaskNotificationScheduling` (defaulting to
   `NotificationManager.shared`), `activeInfos(for:)` for the projection, and an `await` inside the
   already-async `confirmTaskCreation`, with `CancellationError` ignored and other errors logged.

3. **Main-actor blocking on photo save** (`completeDetailedTask` / `savePhotosToDocuments`). Each
   photo cost a full-quality JPEG encode, a downsample, a second encode and a disk write, all on the
   main actor while the completion sheet dismissed.
   **Fix:** `savePhotosToDocuments` is now `nonisolated static`, called through
   `Task.detached(priority: .userInitiated)`. **Correction, 2026-09-08:** this entry used to say
   `@concurrent` "is unavailable at `SWIFT_VERSION = 5.0`". That was **wrong**. `SWIFT_VERSION`
   selects the language mode, not the accepted syntax; the host toolchain is Swift 6.4, and
   `@concurrent` and `nonisolated(nonsending)` compile here today at iOS 18.4. `Task.detached` is
   what shipped and it still works, so this is a possible cleanup, not a blocked one. Measured
   evidence: `docs/swift6-concurrency-assessment.md`.

4. **A deliberate stop reported a dictation failure** (`startDictation`'s `onFailure` closure).
   `stopRecording()` cancels the `SFSpeechRecognitionTask`, and the cancellation comes back through
   the same `onFailure` callback one hop later. Tapping stop — or `endChat`, or `onDisappear` — could
   post a "voice unavailable" bubble for a failure the user never hit.
   **Fix:** `guard let self, isRecording else { return }` in the callback. The synchronous startup
   failure path still reports, so `dictationStartupFailureRestoresIdleState` stays green.

### Reported, not fixed

- `pendingConfirmation`, `taskCompletionRequest` and `taskCreationSession.selectedCats` all hold
  strong references to `@Model` objects across suspension points. Reading a property of a deleted
  model traps. `revalidatePendingActions(against:)` covers the pending cards, and the creation
  session is unreachable while a cat is deleted (the chat hides the tab bar, and `endChat` clears the
  session), so there is no reachable failure today. Worth re-checking if the assistant ever gains a
  path to the My Cats tab without ending the chat.

## Things files 1 to 3 turned up that touch file 4

These are context, not instructions. Judge them yourself.

1. **`NotificationManager.shared` is reached directly from view code.** `TaskAddView:635` and
   `TaskEditView:753` both call the singleton, while `TaskActionService`,
   `TaskManagementViewModel`, `BulkTaskEditService` and now `TaskAssistantViewModel` inject
   `TaskNotificationScheduling`. File 5 owns `TaskEditView`.
2. **`TaskAddView:611` still hand-rolls the `NotificationScheduleInfo` projection** that
   `activeInfos(for:)` owns. File 1 did not catch it; file 3 fixed the copy in its own file.
   `TaskEditView` holds a third copy — that one belongs to file 5.
3. **`scheduleCareTaskNotifications(for:)` is a loop of `await`ed cancel calls followed by a loop of
   `await`ed schedule calls** (`NotificationManager.swift:289`). That is a task-group candidate, but
   check ordering first: the method cancels a task's pending requests *before* it schedules, and
   `BulkTaskEditService` depends on that.
4. **`TaskNotificationScheduling` is `@MainActor` because its methods take `CareTask`.** That is the
   right shape given finding 1 above. Keep it.

## What file 3's fixes changed, in case you touch the same code

- `TaskAssistantViewModel.init` gained a `notificationScheduler:` parameter, placed between
  `taskActionService:` and `speechService:`. Every existing call site uses defaults, so nothing else
  changed.
- `TaskAssistantCloudInterpreting` is `@MainActor`. `FakeTaskAssistantCloudInterpreter` in
  `CatCareCalendarTests/TestSupport/` picks the isolation up by inference and needed no edit; both
  affected test suites were already `@MainActor`.
- No test was added. `NotificationSchedulerSpy` can now be injected into
  `TaskAssistantViewModel` to assert what `confirmTaskCreation` schedules. **That gap is open.**

## Verification commands

The project uses file-system synchronized groups, so a new `.swift` file under `CatCareCalendar/`
joins the target with no `project.pbxproj` edit.

Prefer `xcodebuildmcp`. Call `session_show_defaults` first — it was **unset** at the start of the
file-3 session, so expect to set it:

```text
session_set_defaults({
  projectPath: "<worktree>/CatCareCalendar.xcodeproj",
  scheme: "CatCareCalendar",
  simulatorId: "<iPhone 12, iOS 26.5>",
  bundleId: "com.berkecankizildemir.CatCareCalendar"
})
build_sim({})
test_sim({ extraArgs: ["-only-testing:CatCareCalendarTests"] })
```

One simulator at a time — this machine has 16GB. Unit tests: **283 passed, 0 failed** after file 3's
fixes, on iPhone 12 / iOS 26.5. The run takes about 80 seconds.

`tap` was not available in the file-1 session and was not needed in file 3. If you need taps, check
the tool list before you plan a UI verification, and fall back to `CatCareCalendarUITests`.

## Known limits of the skill setup

Unchanged from `docs/swift-skill-recheck-handoff.md`. In short: the hook only reminds, it does not
enforce; only `Edit`/`MultiEdit`/`Write` fire it; dedupe is per session and substring-based; and the
subagent behavior is still unverified.

The hook was confirmed live on 2026-08-14 in `.claude/settings.local.json`, with matcher
`Edit|MultiEdit|Write`.
