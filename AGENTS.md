# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` is a copy of this file for Codex. Edit `CLAUDE.md`, then copy it to `AGENTS.md`.

## Swift skills are mandatory

Before you write or edit a Swift file under `CatCareCalendar/`, `CatCareCalendarTests/`, or
`CatCareCalendarUITests/`, invoke the matching skill, then edit. This applies to one-line changes
too: a small change to a `body` or an `async` call is where these skills catch the most problems.

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

More than one row can apply — invoke each that does. `ios-memory-perf` is the one exception to
"load it before you edit": it is measure-first, so run it on a reported symptom, a deliberate perf
pass, or a review of image loading, body-read computed properties, or `@Query` cost.
`swiftdata-pro` applies here: this app is local-first on SwiftData, and 45 app-target files import it
(measured 2026-10-02 — recount with
`grep -rl 'import SwiftData' --include='*.swift' CatCareCalendar | wc -l`).
Run the same skills again over the finished change before you end the turn; a `PostToolUse` hook
names them for you. `### Swift review skills` below covers the paths that hook cannot reach.

## Project Overview

CatCareCalendar is a local-first iOS app (SwiftUI + SwiftData) for cat owners to manage care routines, recurring tasks, and history across multiple cats. It targets iOS 18.4+ and uses Swift 6-style patterns (project file now reports `SWIFT_VERSION = 6.0`, verified 2026-09-24 against `project.pbxproj`, all configurations and targets). See the reconciliation notes at the top of "Agent Guide for Swift and SwiftUI" below before applying that section's iOS 26/Swift 6.2 version claims literally.

### Dependencies

The app is local-first, but it is **not dependency-free**. Verified 2026-09-08:

- One Swift package: `firebase-ios-sdk` (`https://github.com/firebase/firebase-ios-sdk`, `upToNextMajorVersion` from `11.7.0`). Four products are linked into the app target: `FirebaseCore`, `FirebaseAuth`, `FirebaseAppCheck`, `FirebaseFunctions`.
- Two app-target files import it: `Utilities/FirebaseBootstrapper.swift` and `Utilities/TaskAssistantCloudInterpreter.swift`.
- Recount with `grep -o 'repositoryURL = [^;]*' CatCareCalendar.xcodeproj/project.pbxproj | sort -u`.

Two consequences an agent must respect:

- **Never set `SWIFT_STRICT_CONCURRENCY = complete` project-wide.** It crashes the compiler on the `FirebaseAuth` target. `docs/swift6-concurrency-assessment.md` and `Config/StrictConcurrency.xcconfig` hold the measured per-file plan instead.
- `Package.resolved` **is tracked in git**, pinning the vendor SDK version so every checkout resolves the same one. Adding another file under `project.xcworkspace/` needs the same trick, so know why: `*.xcworkspace` at `.gitignore:4` ignores the whole **directory**, and git never descends into an ignored directory, so `git add` on a path inside it silently does nothing and a lone `!…/Package.resolved` cannot rescue it. Every parent directory on the path carries its own negating rule (`.gitignore:12-15`). Re-verify with `git check-ignore -v CatCareCalendar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — it prints nothing today.

## Build & Test Commands

```bash
# Open in Xcode (preferred for day-to-day work)
open CatCareCalendar.xcodeproj

# Build from CLI
Scripts/xcb.sh build --os 18.5

# Fast local loop: unit tests only (no UI test build, no coverage)
Scripts/xcb.sh test --scheme CatCareCalendarTests

# Run a single test (Swift Testing suite/test name)
Scripts/xcb.sh test --scheme CatCareCalendarTests --only CatCareCalendarTests/TaskActionServiceTests

# Run full test suite (unit + UI, with coverage) once, before the PR
Scripts/xcb.sh test --os 18.5

# Run UI tests on both the min target (iOS 18.5) and current OS (iOS 26.5),
# one pass after the other; the script shuts down the other simulator first.
Scripts/xcb.sh test --os 18.5 --only CatCareCalendarUITests
Scripts/xcb.sh test --os 26.5 --only CatCareCalendarUITests

# List available simulators (verify device exists before CI-parity runs)
xcrun simctl list devices
```

- Simulator baseline for verification: **iPhone 12, iOS 18.5** (min-target pass) and **iPhone 12, iOS 26.5** (current-OS pass). Run the two passes sequentially — never boot both simulators at the same time; this machine (16GB M2 MacBook Air) can't afford two runtimes resident at once.
- Simulator names, verified 2026-10-06: the 26.5 device is named `iPhone 12`; the 18.5 device is named `iPhone 12 (iOS 18.5)`. `Scripts/xcb.sh` accepts both forms, so `--os 18.5` finds it. A bare `xcodebuild` needs the exact name: `-destination 'platform=iOS Simulator,name=iPhone 12 (iOS 18.5),OS=18.5'`.
- An **iOS 27.0** runtime is installed, but no `iPhone 12` device on it (verified 2026-10-06). It is not the baseline — do not substitute it for the 26.5 pass without saying so, because a result from it is not comparable with the recorded runs.
- Host toolchain as of 2026-09-08: **Xcode 27.0** (build `27A5194q`), **Swift 6.4**. The project's `SWIFT_VERSION = 6.0` (verified 2026-09-24) selects the language mode; it does not limit which syntax this compiler accepts. See the reconciliation notes below.
- Agents build and test through `Scripts/xcb.sh`, never a bare `xcodebuild`. The script holds a machine-wide lock, so builds from every worktree and from TTB queue one at a time on this 16GB Mac; it shares one DerivedData and package checkout across worktrees, so Firebase compiles once. It writes the full log to a file and prints only errors, failures, and the tail. A run can wait minutes for the lock: give it a long Bash timeout or run it in the background. `Scripts/xcb.sh --help` lists the options.
- `Scripts/xcb.sh` is shared with TTB; keep the two copies identical.
- Two schemes. `CatCareCalendarTests` (plan `CatCareCalendarUnitTests.xctestplan`) is the inner loop: it builds the app and the unit test bundle only, skips the UI test target, and collects no coverage. `CatCareCalendar` (plan `CatCareCalendar.xctestplan`) is the full run with UI tests and coverage, and the only scheme that archives. Run the full scheme once before you open a PR: CI (`.github/workflows/test-coverage.yml`) runs it and feeds its result bundle to `Scripts/check_coverage.sh`, which fails on a unit-scheme bundle because that has no coverage. Both plans set `CATCARE_UNIT_TESTING=1` — keep it when you edit either plan.
- When work is split across subagents: only one of them may build, run, or test on a simulator at a time, and xcodebuildmcp session defaults do not reach subagents — pass `simulatorId` and `bundleId` in the prompt. `Localizable.xcstrings`, `project.pbxproj`, `Theme.swift`, `CatCardStyle.swift`, and `NavigationRouter.swift` are single-owner files: subagents report the changes they need, and the coordinating agent applies them (then runs `LocalizationParityTests` after catalog edits).

## Architecture

### App entry & shared state
- `CatCareCalendar/CatCareCalendarApp.swift` is the app entry point. On launch it: builds the `ModelContainer` via `AppLaunchBootstrapper`, ensures a default `Caregiver` exists synchronously (`CaregiverBootstrapper`) to avoid race conditions on first task creation, seeds initial data if needed, and wires a `NotificationActionCoordinator` into `NotificationManager.shared`.
- Environment-based DI: `NavigationRouter.shared`, a `HapticsService`, and the SwiftData `modelContainer` are injected via `.environment(\.navigationRouter, ...)` / `.environment(\.haptics, ...)` using `@Entry`-style environment values — not `EnvironmentObject`.
- `NavigationRouter` (`Utilities/NavigationRouter.swift`) is an `@Observable` singleton owning `NavigationPath`, selected tab, and one-shot navigation flags (`shouldNavigateToMyCats`, `shouldNavigateToHistory`, `shouldTriggerAddTask`) consumed and then reset by the receiving view — this is the single entry point for cross-tab/deep-link navigation (see `AppRoute`/`handle(_:)`). `AppTab` (`ContentView.swift`) has four cases: `home`, `tasks`, `assistant`, `settings`.

### Cloud tier (optional, vendor-backed)

The app is local-first, and everything above works with no network. One feature reaches a server: the task assistant's fallback interpreter.

- `Utilities/FirebaseBootstrapper.swift` (`@MainActor enum`) configures the SDK after the first frame (the root `.task` in `CatCareCalendarApp.swift`) and signs in anonymously. It reads `GoogleService-Info.plist` itself rather than calling a bare `FirebaseApp.configure()`, because that plist is gitignored and a bare configure hard-aborts the app when the file is absent. A checkout without the plist therefore launches normally with the cloud tier disabled.
- `Utilities/TaskAssistantCloudInterpreter.swift` declares the `@MainActor protocol TaskAssistantCloudInterpreting` and the `FirebaseTaskAssistantCloudInterpreter` adapter that calls the `interpretTaskAssistantRequest` Cloud Function. `TaskAssistantViewModel` takes it as an optional injected dependency; tests inject `FakeTaskAssistantCloudInterpreter` from `CatCareCalendarTests/TestSupport/`.
- The protocol is main-actor isolated on purpose: its methods take `[CareTask]`, which are SwiftData models. Do not make it `nonisolated`.

### Feature organization
- `Models/`: the five SwiftData `@Model` types — `Cat`, `CareTask`, `CareTaskSchedule`, `CareTaskCompletion`, `Caregiver` (verified 2026-09-08; recount with `grep -rn -A2 '^@Model' --include='*.swift' CatCareCalendar`). Only `Cat` sits in its own file: the other four are declared in `Models/CareTask.swift`, which is a known exception to the one-type-per-file convention below. `CareTaskTemplate` and `RepeatConfiguration` are **not** persistent models — both are plain `struct`s, so `swiftdata-pro` rules do not govern them. The folder also holds `@Observable` view models (`TaskManagementViewModel`, `TaskAssistantViewModel`) and pure "presentation" structs that derive display-ready data from models (`TaskListPresentation`, `HistoryPresentation`, `HomeRoutineStatusPresentation`, `TaskCalendarPresentation`, `NotificationSettingsPresentation`). These presentation types are the seam most business-logic tests target directly (see the parallel files in `CatCareCalendarTests/Models/`).
- Views stay thin; they read `@Query`/`ModelContext` and delegate to models/services.
- **Bulk task edit is not a feature of this app.** There is no multi-select mode and no production entry point that presents one. This is a product decision, recorded in `docs/adr/0001-no-bulk-task-edit.md` — do not propose the feature. Older documents in `docs/` that describe bulk editing as live describe orphaned code, not a screen a user can reach.
- `Style/Theme.swift` and `Style/CatCardStyle.swift` hold shared visual constants — use these instead of hardcoded colors/fonts.
- `Resources/Localizable.xcstrings` is the single String Catalog holding all localized strings (en + tr); every key must be translated in every locale (see Localization below).
- `documentation/PRD.md` is the source of truth for product scope and success metrics; `documentation/features/` has per-flow specs; `documentation/changelogs/` holds dated change notes — add a dated file there for a substantial change. There is no root `CHANGELOG.md` in this repo.

### Notifications
- Route all local notification scheduling through `NotificationManager` — do not schedule/cancel `UNNotificationRequest`s directly from views or other services. Re-sync notifications whenever a task or its schedule changes.
- Treat any direct `UNUserNotificationCenter.current()` call outside `Utilities/` as a defect. Two remain, verified 2026-09-23 with `git grep -n 'UNUserNotificationCenter.current()'`: both are reads in `Views/Settings/SettingsDebugViews.swift` (delivered and pending notifications in the DEBUG history screen). The file's direct `add(_:)` is gone; the two reads are still open. `NotificationPermissionView` asks for permission through `NotificationManager.requestPermission()`, so an onboarding grant calls `requestFullReminderResync()` like any other. The same method is the named way to ask for one full reminder resync for a non-settings reason; `OnboardingTaskSetupModel` calls it when onboarding saves with stale reminders.
- Care-task writes from views, view models, and services go through `CareTaskWriting` (`Utilities/CareTaskWriting.swift`, implemented by `CareTaskWriter`): `save`, `delete`, `complete`, `snooze`, and `refreshReminders(for:in:)` for a change outside the task, such as a cat rename or delete. Each verb commits, then awaits one full capped resync of every care-task reminder (`TaskNotificationScheduling.resyncAllCareTaskReminders()` → `NotificationResyncCoordinator.resync()`) before it returns; there is no per-task scheduling entry point, because only a pass over every task can keep the pending total at 60 of iOS's 64 slots (#80, `CareTaskReminderSelection`). App activation tops the set up through `NotificationManager.handleAppActivation()`. A failure after the commit throws `CareTaskRemindersOutOfSyncError` ("saved, reminders stale"); callers catch `CancellationError` first, then that error, then everything else ("not saved"). One exception (#7): a failed `delete` commit stays staged, because it cannot be undone; the writer drops the task's snoozes at once and watches `ModelContext.didSave`, so the later save that commits the delete runs one full resync. Do not add a `modelContext.save()` or a `TaskNotificationScheduling` call for a care task outside the writer — `TaskFormPersistence` and `TaskActionService` change models without committing, on purpose. Seeding paths, verified 2026-09-23: `OnboardingDataBuilder` inserts the cat and its starter tasks, then saves each task through the writer, so the first `save` commits them all together; `DebugDataService` commits, then calls `refreshReminders`. Two still commit tasks directly and schedule nothing, on purpose: `PreviewData` (previews must not schedule) and `AppLaunchBootstrapper.seedInitialDataIfNeeded` (runs only under `-ui-testing`, where real notifications are off, from the synchronous `App.init`). Views read the writer from `@Environment(\.careTaskWriter)`, which `CatCareCalendarApp` injects; view models and services take it in `init`. Verified 2026-09-23: `git grep -n 'NotificationManager.shared' -- CatCareCalendar/Views` prints nothing.
- `UserNotificationCenterClient` is the injectable protocol wrapping `UNUserNotificationCenter`; tests use `FakeUserNotificationCenterClient` / `NotificationSchedulerSpy` from `CatCareCalendarTests/TestSupport/` instead of hitting the real notification center.

### SwiftData conventions
- `@Query` is used only inside SwiftUI views; non-view code (services, view models) fetches via `ModelContext` + `FetchDescriptor`.
- Relationships use explicit delete rules (`.cascade`/`.nullify`) and explicit `inverse:` keys — check existing model definitions before adding new relationships.
- The store layout is versioned. `Models/CatCareSchemaV1.swift` (`VersionedSchema`) pins today's five model types and owns the single shared `Schema` instance; `Models/CatCareMigrationPlan.swift` is the `SchemaMigrationPlan`. `AppLaunchBootstrapper`, `PreviewData` and `TestModelContainerFactory` all build their container from `CatCareSchemaV1`. Add a model type only together with a new schema version — never edit V1.
- Filter and sort as close to the query boundary as possible. Prefer explicit saves when correctness matters instead of relying on autosave timing.
- `CatCareCalendarTests/Models/SchemaBaselineTests.swift` pins the V1 store layout with a recorded fingerprint. If a model change makes it fail, that is the point: add a schema version, do not re-record the fingerprint to make the test pass.

## Coding Conventions

These conventions are binding for this repo.

- 4-space indentation, lines <120 chars where practical, one modifier per line for non-trivial view chains.
- `PascalCase` types, `camelCase` members; boolean properties read as questions (`isLoading`, `hasPhoto`, `shouldNavigateToHistory`).
- One major type per file; file name matches its primary type. `// MARK:` only when it materially aids scanability.
- Order view properties: environment, local state, bindings, stored inputs, then computed; keep helpers below `body`.
- Prefer `foregroundStyle()` over `foregroundColor()`; prefer semantic/theme colors over raw `UIColor`.
- Avoid force unwraps in UI/state-management code unless a crash is genuinely the intended behavior.
- State: `@Observable` for shared/non-trivial state, `@State` for view-owned models, `@Binding` for simple parent/child value mutation, `@Environment`/custom environment entries for app-wide dependencies. `@StateObject`/`@ObservedObject`/`@EnvironmentObject` are legacy-interop only — don't introduce them in new code.
- Don't build `Binding(get:set:)` in `body` for business-logic side effects when a model property or `onChange` is clearer; don't store the same domain state in multiple views.
- Navigation: `NavigationStack` only (never `NavigationView`), enum-based typed destinations with `navigationDestination(for:)`, route through `NavigationRouter`. `sheet(item:)` for data-dependent presentation, `sheet(isPresented:)` only for simple booleans.
- No new singletons without a clear app-wide ownership reason; prefer initializer/environment injection.
- Avoid `AnyView` and `GeometryReader` unless genuinely necessary; avoid fixed frames that break Dynamic Type.
- Mark an `@Observable` class `@MainActor` when it mutates state the UI observes. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is now set on the app target (both Debug and Release), so the compiler grants main-actor isolation by default and the explicit `@MainActor` annotation on each of the six `@Observable` classes here (verified 2026-10-02) — `NavigationRouter`, `NotificationManager`, `OnboardingManager`, `OnboardingTaskSetupModel`, `TaskAssistantViewModel`, `TaskManagementViewModel` — restates what the compiler already enforces. Keep writing the explicit annotation on new `@Observable` classes; it documents intent and survives a future change to the project default. Do not assume isolation you did not read in the source or the project settings.
- Concurrency: `.task` for view-scoped async work over `onAppear` + manual `Task {}`; no `[weak self]` in view `.task` closures (views are value types); keep expensive work off the main actor unless it touches UI state.
- Don't swallow user-impacting failures with `print()` alone; surface actionable errors in the UI and keep debug logging secondary.

## Localization

- All user-facing strings live in the String Catalog `Resources/Localizable.xcstrings` (en + tr), with dot-separated keys (e.g. `tasks.header.today`) and `extractionState: "manual"`. `STRING_CATALOG_GENERATE_SYMBOLS = YES` generates typed symbols at build time.
- Access strings via the generated symbols: `Text(.homeCurrentTasks)` in SwiftUI, `String(localized: .tasksTitle)` elsewhere. Parameterized keys generate typed functions — `String(localized: .taskAssistantOpenSuccess(task.title))`; `%d` placeholders take `Int32`, so cast with `Int32(...)`.
- Never call `String(format:)` or `NSLocalizedString` directly for compile-time-known strings. The one sanctioned exception is `String.localizedDataKey` (`Utilities/LocalizationExtensions.swift`) for keys stored as *data* — currently only the persisted `Caregiver.localizationKey` (canonical key constant: `CaregiverBootstrapper.defaultCaregiverLocalizationKey`).
- New keys: add to `Localizable.xcstrings` with translated values for **both** en and tr (state `"translated"`), then use the generated symbol. Plural-sensitive keys use the catalog's `variations.plural` mechanism (see `home.routine_status.days_ago`).
- `LocalizationParityTests` in `CatCareCalendarTests/Utilities/` validates the catalog (every key translated in every locale, plural categories consistent) — run it after touching the catalog.
- Key naming caution: symbol generation camelCases keys, so two keys that differ only in separators (e.g. `foo.some_key` vs `foo.someKey`) collide and break the build — check before adding.
- Spot-check affected UI in both English and Turkish.
- Guard invalid state before formatting user-visible text; return a safe fallback for `nil`, zero, negative, or otherwise invalid values when that's the intended UX. Update formatting tests (ages, weights, counts, dates, reminder copy) when that logic changes.

## Accessibility and testing

Accessibility rules load from `.claude/rules/accessibility.md` when you work in `CatCareCalendar/Views/` or the UI tests. Testing rules load from `.claude/rules/testing.md` when you work in `CatCareCalendarTests/` or `CatCareCalendarUITests/`. Read them before you write a view or a test.

---

## Agent Guide for Swift and SwiftUI (Paul Hudson)

The `swift-style-guide` skill holds this guide, the extended Swift/SwiftUI style standard for this repository. It was written for a green-field iOS 26 project, and this repo predates that — the notes below reconcile its rules with what's actually here, so agents can tell "the standard to write new code against" from "what this codebase currently does."

**Reconciliation notes (read before applying the guide below):**

- **iOS/Swift version.** The project reports `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and `SWIFT_VERSION = 6.0` (verified 2026-09-24, all configurations and targets), not the guide's iOS 26.0 / Swift 6.2. Treat the guide's version numbers as the aspirational target for new code, and flag — don't silently skip — any API the current deployment target can't actually support.
- **Three settings, three different limits. Do not conflate them.** The measured source is `docs/swift6-concurrency-assessment.md`:
  - `SWIFT_VERSION = 6.0` sets the **language mode**. It governs semantics and strictness. It does **not** limit which syntax the Swift 6.4 compiler accepts.
  - The **toolchain** is Swift 6.4 (Xcode 27.0). `@concurrent` and `nonisolated(nonsending)` **do compile today**, at `SWIFT_VERSION = 6.0`, on iOS 18.4. Any document that calls them unavailable here is wrong.
  - `IPHONEOS_DEPLOYMENT_TARGET = 18.4` sets **API availability**. This is the real constraint. It does rule out `Task.immediate`, `InlineArray` and `withTaskPriorityEscalationHandler`, which carry an iOS 26 floor.
  - Moving to Swift 6 language mode does **not** raise the minimum iOS version. iOS 18.4 is safe.
  - See the Dependencies section above before you touch strict-concurrency settings project-wide.
- **Localization mechanism.** This repo now follows the guide's String Catalog approach: `Resources/Localizable.xcstrings` with `extractionState: "manual"` keys and build-generated symbols (`Text(.helloWorld)`-style). The old per-locale `.strings`/`.stringsdict` files and the `localized` / `localized(with:)` helpers were removed in the July 2026 migration. The one deviation: `String.localizedDataKey` remains for keys persisted as data (see Localization above) — do not "fix" it into a symbol.
- **`Formatter`/GCD usage.** The guide's ban on legacy `Formatter` subclasses and its Swift-concurrency-first GCD rule are fully in force: the app target has zero `DateFormatter`/`NumberFormatter`/`MeasurementFormatter`/`DispatchQueue` usage as of July 2026. Use `FormatStyle` (`date.formatted(...)`) and structured concurrency (`Task`, `Task.sleep(for:)`, `@MainActor`) in all new code; callback-based system APIs (camera, speech, notification permission) are bridged with `withCheckedContinuation` in `Utilities/`.

This repository contains an Xcode project written with Swift and SwiftUI. The full generic Swift/SwiftUI/SwiftData API-preference guide (Role, Core/Swift/SwiftUI/SwiftData instructions, project structure, PR instructions) has moved to the `swift-style-guide` skill (`~/.claude/skills/swift-style-guide/SKILL.md`, shared with TTB), so it no longer needs to sit in every session's context. It does **not** load on its own — it is model-invoked, and no hook names it. Invoke it from the routing table at the top of this file, the same way as the other Swift skills. It is a personal skill, so a machine without `~/.claude/skills/swift-style-guide/` does not have it; if that path is missing, say so instead of assuming the guide applied. The reconciliation notes above still apply on top of it.

### xcodebuildmcp (run and UI verification)

The connected Apple-tooling MCP server for this project is **`xcodebuildmcp`**. Use it to install,
launch, and drive the app on the simulator. Builds and tests go through `Scripts/xcb.sh`, because
xcodebuildmcp's `build_*`/`test_*` tools bypass the machine-wide build lock: build with the script,
then `install_app_sim` and `launch_app_sim` with the `.app` path and simulator it prints.
**Do not** use the separate "iOS Simulator control" tool (`mcp__Claude_Code_iOS_Simulator__*`) —
in practice its tap/gesture input fails to reach the app when Xcode is also driving a simulator
(input-focus / dual-simulator conflict); route simulator interaction through `xcodebuildmcp` instead.

First-run setup each session:
- Call `session_show_defaults` before the first build/run/test. If `simulatorId` is unset, set it
  with `session_set_defaults` (e.g. the booted iPhone 12 / iOS 26.5) plus `bundleId`
  `com.berkecankizildemir.CatCareCalendar`. `screenshot`/`snapshot_ui` also require `simulatorId`.

Memory/footprint checks the MCP doesn't cover: measure the running app with
`vmmap --summary <pid> | grep "Physical footprint"` (find the pid via
`pgrep -f "CatCareCalendar.app/CatCareCalendar"`).

---

## Agent skills

### Swift review skills

The table at the top of this file is the routing, and it applies at two moments: load the skill
before you edit, and run it over the finished change before you end the turn. A user-level
`PostToolUse` hook (`~/.claude/hooks/swift-skill-reminder.sh`, registered in
`~/.claude/settings.json`) names the skills you have not loaded yet after any
`Edit`/`MultiEdit`/`Write` on a `.swift` path. Because it is user-level, it fires in every Swift
project on this machine, in Herdr worktrees, and inside subagents (where it reads the subagent's own
transcript). It is not in the repo, so a fresh clone on another machine does not have it. See
`docs/swift-skill-trigger-setup.md`.

The table still applies where the hook cannot fire: edits made through Bash, through
`xcodebuildmcp`, by the user in Xcode, or on a machine without the hook.
`.claude/rules/swift-skills.md` carries the same routing and fires when an agent reads a Swift
file here.

Run one review of the finished change, not one per edit. `swift-style-guide` covers every Swift
edit here, so a plain value type with none of the other markers still gets that one row. The hook
deliberately leaves `ios-memory-perf` out, for the measure-first reason `## Swift skills are
mandatory` gives at the top of this file — that block is the one place this repo states the
triggers. The hook names neither `ios-memory-perf` nor `swift-style-guide`, so the table is the
only route to both.

TTB is the other iOS project on this machine. It shares the same hook script; the script names
`swiftdata-pro` only for files that use SwiftData, so it stays silent in TTB. Both repos carry the `swift-style-guide` row: the skill lives in `~/.claude/skills`, and each
repo's `CLAUDE.md` holds its own version reconciliation. The two repos cannot contaminate each other: `.claude/skills/` loads only for its own repo, and
only `~/.claude/skills` is shared.

`CODING_STANDARDS.md` points review agents (for example `mattpocock-skills:code-review`, whose
standards agent reads that file) at this file's conventions and the Swift skills.

### Issue tracker

Issues live as GitHub issues in `bckizildemir/Purrtine`, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, used verbatim as label strings. All five exist in the tracker as of 2026-09-09. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Documentation audits

`docs/agents/doc-audit-2026-09.md` is the claim-by-claim audit of this file and the rest of the agent-facing docs, dated 2026-09-08. It records what was verified, what was false, and the six items that need a human decision. Two habits it asks of you:

- Every count in these documents carries the date it was measured. Trust the date, not the number — five of seven counts drifted in six weeks. Re-measure before you quote one.
- Verify an **absolute** claim before you rely on it ("all X goes through Y", "no dependencies", "API Z is unavailable"). Those are the claims that read as permission to skip a check, and every one this audit tested was wrong.
