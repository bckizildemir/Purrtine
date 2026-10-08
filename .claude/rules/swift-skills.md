---
paths:
  - "CatCareCalendar/**/*.swift"
  - "CatCareCalendarTests/**/*.swift"
  - "CatCareCalendarUITests/**/*.swift"
---

# Swift work requires a Swift skill

You have just read a Swift file in this repo. Before you write or edit any Swift here,
invoke the matching skill. Load it first, then edit. Do not skip this because the change
looks small — a one-line change to a `body` or an `async` call is exactly where these
skills catch problems.

| You are touching                                                   | Invoke                  |
| ------------------------------------------------------------------ | ----------------------- |
| Any SwiftUI view, layout, or `@State`/`@Observable` code            | `swiftui-pro`           |
| A new screen or component; tab, route, or sheet structure           | `swiftui-ui-patterns`   |
| `@Model`, `@Query`, `ModelContext`, `FetchDescriptor`               | `swiftdata-pro`         |
| `async`/`await`, `Task`, actors, `Sendable`, `@MainActor`           | `swift-concurrency-pro` |
| Any test file — UI tests stay on XCTest                             | `swift-testing-pro`     |
| `glassEffect`, `GlassEffectContainer`, iOS 26 chrome                | `swiftui-liquid-glass`  |
| Navigation titles, toolbars, `ToolbarSpacer`                        | `ios-navigation-chrome` |
| Anything perf-shaped: scroll, memory, launch, image decode          | `ios-memory-perf`       |
| Any Swift file — modern-API choice over legacy, naming, structure   | `swift-style-guide`     |

More than one row can apply — invoke each that does, and `swift-style-guide` applies to every Swift
edit here. `ios-memory-perf` is the one exception to "load it before you edit": it is measure-first,
so run it on a reported symptom, a deliberate perf pass, or a review of image loading, body-read
computed properties, or `@Query` cost.

`swift-style-guide` is a personal skill in `~/.claude/skills/`, shared with TTB, and it is
model-invoked: nothing loads it for you, and the `PostToolUse` hook does not name it. This row is
its only route.

`swiftdata-pro` applies here. This app is local-first on SwiftData: 45 app-target files import it (2026-10-02),
and the five `@Model` types (`Cat`, `CareTask`, `CareTaskSchedule`, `CareTaskCompletion`,
`Caregiver`) carry the whole domain. `CareTaskTemplate` and `RepeatConfiguration` are plain structs,
not models — do not treat them as persistent. This is the one row where TTB differs: TTB persists
through Firestore and drops the skill.

## Repo facts these skills should know

A count below that carries its own date was measured on that date; the others were measured on
2026-09-08. Re-measure rather than quote them if a decision turns on one.

- Deployment target is iOS 18.4, so an iOS 26 API needs an availability guard. Seven files already
  use Liquid Glass (2026-10-02) — follow the shim pattern they establish rather than a new one. Report an
  iOS 26-only fix as a gap, not as the fix.
- The project reports `SWIFT_VERSION = 6.0` (verified 2026-09-24, all configurations and targets),
  which selects the **language mode** only. The host toolchain is Swift 6.4 (Xcode 27.0), so
  `@concurrent` and `nonisolated(nonsending)` **do compile here**. Availability, not language mode,
  is what iOS 18.4 constrains. See `CLAUDE.md`'s reconciliation notes and
  `docs/swift6-concurrency-assessment.md`.
- The project depends on the `firebase-ios-sdk` Swift package (four products, two importing files).
  Never enable `SWIFT_STRICT_CONCURRENCY = complete` project-wide: it crashed the compiler on the
  `FirebaseAuth` target when tried, and no config in `project.pbxproj` sets it now (verified
  2026-09-24).
- Swift Testing is the default for unit and integration suites. XCTest is reserved for
  `CatCareCalendarUITests`, where one file uses it. Match the file you are editing.
- `CatCareCalendarTests/TestSupport/` provides `TestModelContainerFactory`,
  `FakeUserNotificationCenterClient`, `NotificationSchedulerSpy`, `FakeTaskAssistantCloudInterpreter`
  and `SchemaBaselineHarness`. Use these instead of real persistence, notification or network state.
- The store layout is versioned in `Models/CatCareSchemaV1.swift`. Adding or changing a `@Model`
  needs a new schema version, and `SchemaBaselineTests` will fail until it gets one.
- Mark an `@Observable` type `@MainActor` when it mutates state the UI observes.
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is now set on the app target (Debug and Release), so
  the compiler grants main-actor isolation by default. Every `@Observable` class here still carries
  the explicit `@MainActor` annotation too, which restates the default rather than overriding it.
  Read the source before you assume otherwise.
- Route all local notification scheduling through `NotificationManager`. Treat any direct
  `UNUserNotificationCenter.current()` call outside `Utilities/` as a defect. None remain, verified
  2026-10-08 with `git grep -n 'UNUserNotificationCenter.current()' -- CatCareCalendar`, which
  prints nothing (the one wrapper, `SystemUserNotificationCenterClient` in `Utilities/`, takes
  `.current()` as a default argument). The DEBUG Notification History screen reads through
  `NotificationManager`'s DEBUG-only `deliveredNotificationsForHistory()` and
  `pendingTestNotificationRequests()` (#8).
