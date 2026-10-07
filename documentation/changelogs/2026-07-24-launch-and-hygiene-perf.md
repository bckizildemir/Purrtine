# Launch & Hygiene (Perf Batch 4) — 2026-07-24

Fourth execution batch from `documentation/performance-improvement-plan.md` (items P2.10, P2.11, P2.12).
Small correctness/hygiene wins plus getting third-party SDK setup off the launch critical path.

## Changes

### P2.10 — Firebase off the launch critical path
- `CatCareCalendarApp.swift`: moved `FirebaseBootstrapper.configureIfNeeded()` and the anonymous
  sign-in out of `App.init` into a `.task` on the root `ContentView`, so Firebase's synchronous
  setup no longer runs before the first frame. The task-assistant cloud tier is the only consumer,
  and `TaskAssistantCloudInterpreter` already fails gracefully to the on-device heuristic if it runs
  before configuration completes, so the deferral is safe.

### P2.11 — Actor hygiene (partial)
- `Views/Tasks/TaskCompletionView.swift`: the photo picker decoded `UIImage(data:)` inside a plain
  `Task {}` — and because SwiftUI's `View` is `@MainActor`, that decode ran on the main actor. It is
  now offloaded via `Task.detached`. Removed the accompanying redundant `MainActor.run` wrappers in
  `loadPendingLibraryItem` and `openCamera` (the enclosing view is already main-actor isolated).
- Confirmed the Batch 1 CatFormView async refactor is correct for the same reason (heavy work in
  `Task.detached`, state/model mutations on the main actor).

Deferred (documented, not done): adding `@MainActor` to the `@Observable` singletons. It gives no
performance benefit and cascades: `NavigationRouter` forced `AppLaunchBootstrapper.applyLaunchStateIfNeeded`
to change and produced "future-error" warnings from the `@Entry navigationRouter = .shared` default;
`OnboardingManager` would require making its (non-isolated) test suite and the bootstrapper main-actor.
These belong in a dedicated strict-concurrency pass, not a hygiene batch. The per-render `fileExists`
stat in `PhotoManager.getPhotoURL` and the cosmetic `MainActor.run` removals in other views were also
left as-is (zero perf impact).

### P2.12 — Logging & dead code
- `Utilities/NotificationManager.swift`: added a `debugLog(_:)` helper that compiles out in release
  and routed the scheduling/cancel/resync `print()` calls through it (they used to run with string
  interpolation in production — the "Cancelled N notifications" spam seen in the memory screenshots).
- Deleted unused code: `PhotoManager.generateThumbnail`, `PhotoManager.loadPhoto`, and
  `CareTaskCompletion.timeAgoText` (the last used the banned `RelativeDateTimeFormatter`).

## Verification
- `xcodebuildmcp` `build_sim` clean, zero warnings.
- Full `CatCareCalendarTests` unit target green (166 tests).
- `build_run_sim` launches clean on iPhone 12 / iOS 26.5 (Firebase now brought up post-first-frame).

## Notes
- `CareTask.photoURLs` (task-completion proof photos, written but seemingly never displayed) is still
  flagged in the plan as needing a product decision — untouched here.
