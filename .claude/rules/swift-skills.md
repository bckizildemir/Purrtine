---
paths:
  - "Purrtine/**/*.swift"
  - "PurrtineTests/**/*.swift"
  - "PurrtineUITests/**/*.swift"
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
| Any SwiftUI view — Apple's own SwiftUI guidance (with `swiftui-pro`) | `swiftui-specialist`    |
| iOS 27 SwiftUI API: `reorderable`, swipe actions outside `List`, toolbar overflow, `@State` macro errors | `swiftui-whats-new-27`  |
| An XCTest file, or moving a test to Swift Testing (with `swift-testing-pro`) | `modernize-tests`       |
| Profiling with Instruments or `xctrace` (with `ios-memory-perf`)    | `xctrace`               |
| App Intents, Shortcuts, Siri, widget configuration intents          | `app-intents-specialist`, `app-intents-whats-new-27` |

The five rows above under the style-guide row are Apple's own skills, exported from Xcode 27 with
`xcrun mcpbridge run-agent skills export` into `~/.claude/skills/` (2026-11-11). Their text says it supersedes
older training; when one disagrees with a community skill above, follow Apple's. Re-export after each Xcode update
(`--replace-existing`).

**Newer-iOS APIs go through `Backport`.** The deployment target is iOS 18.4, and `swiftui-whats-new-27`,
`app-intents-whats-new-27` and the Liquid Glass skills teach iOS 26/27-only API. Wrap each such API in the
existing backport system: `Purrtine/Utilities/Backport.swift` (`view.backport.<name>(…)`, or `Backport.<Name>` for
toolbar content), one `Purrtine/Utilities/Backport+<Feature>.swift` per API, with `if #available(iOS 26.0, *)` (or
27.0) inside it and a fallback for older iOS (the old look, or nothing when the feature is cosmetic). Do
not add a new `#available` check in a view; reuse or add a `Backport+` file. Example: `Backport+ToolbarSpacer.swift`.

More than one row can apply — invoke each that does, and `swift-style-guide` applies to every Swift
edit here. `ios-memory-perf` is the one exception to "load it before you edit": it is measure-first,
so run it on a reported symptom, a deliberate perf pass, or a review of image loading, body-read
computed properties, or `@Query` cost.

`swift-style-guide` is a personal skill in `~/.claude/skills/`, shared with TTB, and it is
model-invoked: nothing loads it for you, and the `PostToolUse` hook does not name it. This row is
its only route. A machine without `~/.claude/skills/swift-style-guide/` does not have it: say so
instead of assuming the guide applied.

`swiftdata-pro` applies here. This app is local-first on SwiftData: 45 app-target files import it (2026-10-02;
recount with `grep -rl 'import SwiftData' --include='*.swift' Purrtine | wc -l`),
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
  is what iOS 18.4 constrains. See "Version reconciliation" below and
  `docs/swift6-concurrency-assessment.md`.
- The project depends on the `firebase-ios-sdk` Swift package (four products, two importing files).
  Never enable `SWIFT_STRICT_CONCURRENCY = complete` project-wide: it crashed the compiler on the
  `FirebaseAuth` target when tried, and no config in `project.pbxproj` sets it now (verified
  2026-09-24).
- Swift Testing is the default for unit and integration suites. XCTest is reserved for
  `PurrtineUITests`, where one file uses it. Match the file you are editing.
- `PurrtineTests/TestSupport/` provides `TestModelContainerFactory`,
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
  2026-10-08 with `git grep -n 'UNUserNotificationCenter.current()' -- Purrtine`, which
  prints nothing (the one wrapper, `SystemUserNotificationCenterClient` in `Utilities/`, takes
  `.current()` as a default argument). The DEBUG Notification History screen reads through
  `NotificationManager`'s DEBUG-only `deliveredNotificationsForHistory()` and
  `pendingTestNotificationRequests()` (#8).

## Version reconciliation

The `swift-style-guide` skill was written for a green-field iOS 26 project, and this repo predates that. These
notes reconcile its rules with what is here: "the standard to write new code against" versus "what this
codebase does now". Read them before you apply the guide.

- **iOS/Swift version.** The project reports `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and `SWIFT_VERSION = 6.0` (verified 2026-09-24, all configurations and targets), not the guide's iOS 26.0 / Swift 6.2. Treat the guide's version numbers as the aspirational target for new code, and flag — don't silently skip — any API the current deployment target can't actually support.
- **Three settings, three different limits. Do not conflate them.** The measured source is `docs/swift6-concurrency-assessment.md`:
  - `SWIFT_VERSION = 6.0` sets the **language mode**. It governs semantics and strictness. It does **not** limit which syntax the Swift 6.4 compiler accepts.
  - The **toolchain** is Swift 6.4 (Xcode 27.0). `@concurrent` and `nonisolated(nonsending)` **do compile today**, at `SWIFT_VERSION = 6.0`, on iOS 18.4. Any document that calls them unavailable here is wrong.
  - `IPHONEOS_DEPLOYMENT_TARGET = 18.4` sets **API availability**. This is the real constraint. It does rule out `Task.immediate`, `InlineArray` and `withTaskPriorityEscalationHandler`, which carry an iOS 26 floor.
  - Moving to Swift 6 language mode does **not** raise the minimum iOS version. iOS 18.4 is safe.
  - See "Dependencies" in `CLAUDE.md` before you touch strict-concurrency settings project-wide.
- **Localization mechanism.** This repo now follows the guide's String Catalog approach: `Resources/Localizable.xcstrings` with `extractionState: "manual"` keys and build-generated symbols (`Text(.helloWorld)`-style). The old per-locale `.strings`/`.stringsdict` files and the `localized` / `localized(with:)` helpers were removed in the July 2026 migration. The one deviation: `String.localizedDataKey` remains for keys persisted as data (see `.claude/rules/localization.md`) — do not "fix" it into a symbol.
- **`Formatter`/GCD usage.** The guide's ban on legacy `Formatter` subclasses and its Swift-concurrency-first GCD rule are fully in force: the app target has zero `DateFormatter`/`NumberFormatter`/`MeasurementFormatter`/`DispatchQueue` usage as of July 2026. Use `FormatStyle` (`date.formatted(...)`) and structured concurrency (`Task`, `Task.sleep(for:)`, `@MainActor`) in all new code; callback-based system APIs (camera, speech, notification permission) are bridged with `withCheckedContinuation` in `Utilities/`.

## The hook and the review pass

The table applies at two moments: load the skill before you edit, and run it over the finished change
before you end the turn. Run one review of the finished change, not one per edit.

A user-level `PostToolUse` hook (`~/.claude/hooks/swift-skill-reminder.sh`, registered in
`~/.claude/settings.json`) names the skills you have not loaded yet after any `Edit`/`MultiEdit`/`Write`
on a `.swift` path. It fires in every Swift project on this machine, in worktrees, and inside subagents
(where it reads the subagent's own transcript). It is not in the repo, so a fresh clone on another machine
does not have it. See `docs/swift-skill-trigger-setup.md`.

The table is the only route where the hook cannot fire: edits made through Bash, through `xcodebuildmcp`,
by the user in Xcode, or on a machine without the hook. The hook names neither `ios-memory-perf`
(measure-first, see above) nor `swift-style-guide`, so the table is the only route to both.

TTB shares the hook script; the script names `swiftdata-pro` only for files that use SwiftData, so it
stays silent in TTB. Each repo holds its own version reconciliation.
