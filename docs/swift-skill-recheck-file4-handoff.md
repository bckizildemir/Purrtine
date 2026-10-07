# Handoff — file 4 of the Swift skill recheck: `Utilities/NotificationManager.swift`

**Written:** 2026-08-14 · **Scope:** one review pass over one file · **Run this at medium effort.**

> **CLOSED — status re-checked 2026-09-08.** The five-file pass finished on 2026-08-14 and every file
> was reviewed and fixed. This document is kept as a record of the brief, not as work to pick up.
> Do not act on the "Your job" and "Not started" rows below: they describe the mid-pass state of
> 2026-08-14. The closing summary is `docs/swift-skill-recheck-summary.md`. Everything under this
> banner is the original brief, corrections marked in place.

## Where this sits

This continues `docs/swift-skill-recheck-file3-handoff.md`, which continues
`docs/swift-skill-recheck-file2-handoff.md`, which continues `docs/swift-skill-recheck-handoff.md`.
Read them first. Do not repeat their evidence work.

> ~~**`docs/swift-skill-recheck-handoff.md` is still not on this branch.**~~ **Resolved 2026-09-08.**
> That document and the **Swift review skills** route table in `CLAUDE.md` are both on `main` now.
> Read them from `main`; branch `fix/remove-orphan-cats-selection-done` no longer matters here.

Status of the five files:

| # | File (under `CatCareCalendar/`) | Skills | State |
| --- | --- | --- | --- |
| 1 | `Views/Tasks/TaskAddView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | Reviewed **and fixed** on 2026-08-14 |
| 2 | `Models/CareTask.swift` | `swiftdata-pro` | Reviewed **and fixed** on 2026-08-14 |
| 3 | `Models/TaskAssistantViewModel.swift` | `swiftdata-pro`, `swift-concurrency-pro` | Reviewed **and fixed** on 2026-08-14 |
| 4 | `Utilities/NotificationManager.swift` | `swift-concurrency-pro` | Reviewed **and fixed** on 2026-08-14 |
| 5 | `Views/Tasks/TaskEditView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | **Your job** |

## Your job

Run **`swiftui-pro`**, **`swift-concurrency-pro`** and **`ios-navigation-chrome`** over
`CatCareCalendar/Views/Tasks/TaskEditView.swift`. The routing was verified against these exact files
on 2026-08-14. Trust it; do not re-derive it.

This is the last file in the pass, and it is the twin of file 1. File 1 is your best guide: the same
three skills ran over near-identical code, and its fixes created the seams you should reuse instead
of writing new ones.

**Report first, then fix.** Files 1 to 4 all ran as report-then-fix, with the user granting the
go-ahead in the same turn. Expect the same.

## Rules for the pass

- **Group findings by severity.** Real problems only. The skill bodies say "Report only genuine
  problems - do not nitpick or invent issues." Honour that.
- **Reconcile against this repo's reality.** `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and
  `SWIFT_VERSION = 5.0`. A finding that assumes iOS 26 or Swift 6.2 is not actionable here. Flag the
  gap; do not report the iOS 26 or Swift 6.2 API as the fix. **Correction, 2026-09-08:**
  `@concurrent` used to be given here as the standing example of an unreachable API. It is not one.
  `SWIFT_VERSION = 5.0` sets the language mode, not the accepted syntax, and `@concurrent` compiles
  on this toolchain (Swift 6.4) at iOS 18.4. The genuine limit is API availability from the 18.4
  deployment target. See the reconciliation notes in `CLAUDE.md` and
  `docs/swift6-concurrency-assessment.md`.
- **`ios-navigation-chrome` is iOS 26-shaped.** File 1 already reconciled it against the 18.4 target.
  Read what file 1 concluded before you propose toolbar or subtitle changes.
- **CloudKit rules do not apply — this is settled.** File 3 checked it. Do not re-derive.
- **Do not run `ios-memory-perf`.** It is measure-first and symptom-triggered, and it is deliberately
  outside the routing table. Main-actor blocking is still a fair `swift-concurrency-pro` finding, but
  do not turn the pass into a perf audit.

## What file 4 found and fixed

Commit `b44961f`, "fix: make notification scheduling cooperate with cancellation". One finding
applied, three reported and not fixed.

### High

1. **Cancellation was never checked, so every cancel of the scheduling path was inert**
   (`scheduleCareTaskNotifications`, `scheduleNotificationForSchedule`). Both loop over up to 30
   `await notificationCenter.add(_:)` calls per schedule. `UNUserNotificationCenter.add(_:)` throws
   `UNError`, never `CancellationError`, and no loop called `Task.checkCancellation()`. Three
   consequences, all live before the fix:
   - `NotificationResyncCoordinator.scheduleResync()` calls `previousTask?.cancel()` and then
     `await previousTask?.value`. The cancelled run ran to completion and the new run waited for it,
     so each settings toggle or authorization change queued a whole serial rebuild.
   - The `catch is CancellationError { return }` in `resyncCareTaskNotifications` was dead code.
   - `TaskAddView:636` (file 1's fix) and `TaskAssistantViewModel:414` (file 3's fix) both catch
     `CancellationError` from this method. Neither handler could ever run.

   **Fix:** `try Task.checkCancellation()` at the top of the schedule loop and at the top of the
   per-date add loop, plus `Task.isCancelled` in the `resyncCareTaskNotifications` guard. The checks
   are **deliberately absent from the cancel loop**: abandoning a cancel pass leaves stale requests
   that still fire, while abandoning an add pass is safe because the next resync rebuilds the set
   from the store. That asymmetry is load-bearing — do not "finish" it.

   Collateral, required by the fix: `BulkTaskEditService:141` and `CatReminderRefreshService:20` both
   logged every error, so newly reachable cancellation would have surfaced as a scheduling failure.
   Both now filter `CancellationError` first.

### Reported, not fixed

2. **Medium — cancel-then-add spans suspension points, so two concurrent callers interleave**
   (`scheduleCareTaskNotifications:289-303`). The method is `@MainActor`, but `await` releases the
   main actor. Concrete failure: a task save calls `scheduleCareTaskNotifications([X])`, which
   cancels X and starts adding `X_0`; `scheduleResync` interleaves, runs
   `cancelAllCareTaskNotifications()` — which removes the just-added `X_0` — and reschedules from a
   snapshot taken before X was saved. The view's remaining adds then land. X keeps its later
   reminders and silently loses the earliest one.

   Not fixed because every cheap serialization deadlocks: `scheduleCareTaskNotifications` calls
   `cancelCareTaskNotifications` internally, so a single serial gate around the public methods makes
   the inner call wait on its own outer call. A correct fix needs private unserialized internals plus
   a `withTaskCancellationHandler` bridge so the gate does not undo finding 1. **Note for whoever
   takes this on:** `Utilities/InFlightMainActorOperation.swift` already exists and looks like the
   seam, but it *coalesces* concurrent callers onto one operation. Coalescing two schedule calls with
   different `infos` would drop one of them. It is the wrong tool here.

3. **Low — `applySettings:277` fires `Task { await self.syncBadgeCount() }` with no handle.** Benign:
   `syncBadgeCount`'s `badgeSyncToken` guard already makes the last writer win, and `clearBadge()`
   invalidates in-flight syncs (`NotificationManagerBadgeTests` covers both). The only cost is that
   callers cannot await the badge result. `applySettings` is called synchronously from two views, so
   making it async is a view-level change.

4. **Low — `extension NotificationManager: @preconcurrency UNUserNotificationCenterDelegate`
   (line 633).** The iOS 18.4 SDK header carries no `NS_SWIFT_UI_ACTOR` on that protocol, so
   main-actor isolation here is a dynamic precondition, not a static guarantee: an off-main callback
   traps rather than races. UserNotifications delivers on the main queue in practice, and the
   alternatives (a `nonisolated` shim that hops) either keep the same assumption or delay
   `completionHandler`. Accepted as-is; recorded so it is not rediscovered.

### Checked and rejected

- **File 3's handoff item 3 — task group for the cancel and schedule loops.** Rejected, and the
  ordering caveat was the smaller half of the reason. The cancel pass must precede the add pass
  (`BulkTaskEditService:135-139` depends on it); the client is `@MainActor`, so a group buys only
  overlapped XPC latency; and it would destroy the deterministic `addedRequests` order that
  `NotificationManagerSchedulingTests` asserts.
- **Batching the per-task cancel pass into one `pendingNotificationRequests()` fetch.** Real but
  minor: `resyncCareTaskNotifications` pays N+1 XPC round trips where 2 would do. Rejected because it
  is latency, not correctness, and because
  `NotificationManagerSchedulingTests.mixedTaskBatchCancelsEveryTaskWithoutTouchingUnrelatedNotifications`
  asserts the exact call grouping (`removedPendingIdentifiers == [["first-old"], ["second-old"]]`).
  Rewriting a green test to fit a performance tweak was outside this pass. Pick it up with the
  finding-2 refactor, where the suspension points are being reduced anyway.
- **`nonisolated static let shared` with `MainActor.assumeIsolated` (line 150).** Safe. Every access
  path is `@MainActor`, and the one nonisolated caller, `CatCareCalendarApp.init`, runs on the main
  thread.
- **`NotificationSettingsStore` load/save on the main actor.** `UserDefaults` plus a six-field JSON
  blob. Not a finding.

## Things files 1 to 4 turned up that touch file 5

These are context, not instructions. Judge them yourself.

1. **`TaskEditView:753` is `Task { try? await NotificationManager.shared.scheduleCareTaskNotifications(...) }`.**
   Three problems in one line, and file 1 fixed the same line in `TaskAddView`: it swallows every
   error with `try?`, it reaches the singleton from view code, and it is fire-and-forget. After
   finding 1 above, that `try?` now also swallows a real `CancellationError` — which is the one error
   it *should* ignore, so match file 1's shape: `catch is CancellationError` plus a logged `catch`.
   Compare `TaskAddView:633-641` and `TaskAssistantViewModel:410-418`.
2. **`TaskEditView` holds the third hand-rolled `NotificationScheduleInfo` projection.**
   `NotificationScheduleInfo.activeInfos(for:)` owns it. Files 1 and 3 removed their copies. This is
   the last one.
3. **Injection.** `TaskActionService`, `TaskManagementViewModel`, `BulkTaskEditService` and
   `TaskAssistantViewModel` all inject `TaskNotificationScheduling` (`@MainActor`, and it stays that
   way — its methods take `CareTask`). **Correction, 2026-09-08:** this entry claimed `TaskEditView`
   was "the only remaining direct `NotificationManager.shared` caller in view code". It was not.
   `TaskAddView` and `TaskEditView` both call it — count them yourself with
   `git grep -n 'NotificationManager.shared' -- CatCareCalendar/Views`. `BulkTaskEditService` appears
   above as July's code; bulk task edit is not a feature and its code is deleted.
4. **`FeedingFieldSupport` is the seam to reuse.** File 1 pulled the feeding portion encode, decode
   and display rules out of `TaskAddView` into it. `TaskEditView` still holds near-identical feeding
   code that file 1 deliberately did not touch. **No tests cover `FeedingFieldSupport` yet** — that
   gap is still open, and reusing it from a second view raises the value of closing it.
5. **`colorForCategory` (`TaskEditView:757`) is the fourth copy of the same switch.** File 2 was the
   natural home for a `color` property on `CareTaskCategory`. Check whether file 2 added one before
   you copy the switch forward.

## What file 4's fixes changed, in case you touch the same code

- `scheduleCareTaskNotifications(for:)` can now throw `CancellationError`. Any new call site must
  filter it before logging.
- No public signature changed. No test changed. No test was added — **`NotificationSchedulerSpy`
  still cannot assert cancellation behavior, and nothing covers the new checks.** That gap is open,
  and it is the same shape as the gap file 3 left.

## Verification commands

The project uses file-system synchronized groups, so a new `.swift` file under `CatCareCalendar/`
joins the target with no `project.pbxproj` edit.

Prefer `xcodebuildmcp`. Call `session_show_defaults` first — it was **unset** at the start of the
file-3 and file-4 sessions, so expect to set it:

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

One simulator at a time — this machine has 16GB. In the file-4 session the iPhone 12 / iOS 26.5
simulator is `4AD389C4-F709-4D96-8F4D-E497AD3C2E67`; verify with `list_sims` rather than trusting
that identifier. Unit tests: **283 passed, 0 failed** after file 4's fix. The build takes about 20
seconds and the test run about 66 seconds.

`tap` was not available in the file-1 session and was not needed in files 3 or 4. File 5 is a view,
so it is the most likely of the five to want on-simulator verification: check the tool list before
you plan it, and fall back to `CatCareCalendarUITests`.

## Known limits of the skill setup

Unchanged. In short: the hook only reminds, it does not enforce; only `Edit`/`MultiEdit`/`Write` fire
it; dedupe is per session and substring-based; and the subagent behavior is still unverified.

One new observation from file 4: the hook fires per changed Swift file and names a skill by file
type, not by the routing table. Editing `BulkTaskEditService.swift` — a two-line `catch` clause —
produced a reminder to run `swiftdata-pro` over it. The routing table is the authority for this pass,
so that reminder was recorded and not followed. Expect the same noise in file 5.
