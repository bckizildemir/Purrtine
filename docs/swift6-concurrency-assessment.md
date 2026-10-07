# Swift 6 language mode + strict concurrency: measured assessment

**Date:** 8 September 2026 · branch `chore/swift6-concurrency-assessment` · base `main` @ `5b8b332`
**Toolchain:** Apple Swift 6.4 (swiftlang-6.4.0.20.104), Xcode 27.0 (27A5194q)
**Project:** `IPHONEOS_DEPLOYMENT_TARGET = 18.4`, `SWIFT_VERSION = 5.0` in all 6 build configurations,
`SWIFT_STRICT_CONCURRENCY` unset, no `SWIFT_UPCOMING_FEATURE_*` flags set.

Every number in this document comes from a build. No number is an estimate. The method is in
[Appendix A](#appendix-a--measurement-method).

---

## 1. Verdict on iOS 18

**Swift 6 language mode does not raise the minimum iOS version. iOS 18.4 stays reachable.**

The Swift language mode is a compile-time setting. The concurrency runtime that Swift 6 mode depends
on back-deploys, so the compiler does not add an availability floor when you change the mode. This
project proves it directly: 10 builds ran against `arm64-apple-ios18.4-simulator`, across Swift 5
mode, Swift 5 + `SWIFT_STRICT_CONCURRENCY = complete`, Swift 6 mode, and Swift 6 mode +
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `NonisolatedNonsendingByDefault`. A grep across all 10
build logs for `only available in iOS`, `is unavailable`, and `requires iOS` returns **zero hits**.
Not one diagnostic in any stage was an availability diagnostic.

The migration also does not need any API that carries a floor above iOS 18.4. Direct probes with
`swiftc -target arm64-apple-ios18.4-simulator -swift-version 6`:

| API | iOS 18.4 | Needed by this migration? |
| --- | --- | --- |
| `Synchronization.Mutex` | OK | No (optional tool for a `nonisolated` cache) |
| `Synchronization.Atomic` | OK | No |
| `isolated deinit` | OK | No |
| `Task(name:)` | OK | No |
| `Task.immediate` | **iOS 26.0** | No |
| `withTaskPriorityEscalationHandler` | **iOS 26.0** | No |
| `InlineArray` | **iOS 26.0** | No |
| `Span` / `Array.withSpan` | absent from this SDK surface | No |

Three Swift 6.2-era APIs do carry an iOS 26.0 floor. All three are optional conveniences. None of
them appears in any fix this assessment recommends, and none is required to enter Swift 6 mode. Keep
them out of the app target while iOS 18 is the minimum, and the floor never becomes a problem.

`@MainActor`, `@concurrent`, `nonisolated(nonsending)`, `sending`, and
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` are all compile-time constructs with no availability
floor. They are the entire toolkit this migration needs.

### Correction to a stated premise: this project has a third-party dependency

The brief states "zero third-party dependencies." That is wrong, and it changes one conclusion.

`CatCareCalendar.xcodeproj/project.pbxproj` carries an `XCRemoteSwiftPackageReference` on the
Google `firebase-ios-sdk` repository, `upToNextMajorVersion` from `11.7.0`, with four product
dependencies: `FirebaseCore`, `FirebaseAppCheck`, `FirebaseAuth`, `FirebaseFunctions`. Two app files
import it: `Utilities/FirebaseBootstrapper.swift` and `Utilities/TaskAssistantCloudInterpreter.swift`.
A clean build compiles the whole vendor source tree from SwiftPM.

Two consequences:

1. **No deployment-target risk from the vendor SDK.** It builds at
   `-target arm64-apple-ios15.0-simulator` in this project, below the app's 18.4. It does not push
   the floor up.
2. **The concurrency setting must be target-scoped, not global.** A command-line
   `SWIFT_STRICT_CONCURRENCY=complete` applies to the SwiftPM package targets too, and it **crashes
   the Swift compiler** while it builds the `FirebaseAuth` target (stack dump,
   `Command SwiftCompile failed`, `** BUILD FAILED **`). Set the value on the app target's build
   configurations, or in an `.xcconfig` that the app target consumes. Never pass it on the
   `xcodebuild` command line for this project.

---

## 2. Measured diagnostic counts

Counts are unique `file:line:col: kind: message` diagnostics whose path is inside this worktree.
Diagnostics from the vendor SDK and from the platform SDK are excluded. "Coverage" is the number of
the app target's 167 `.swift` files that the compiler reached; 163 is the full set (4 files are not
in the app target's compile sources).

### App target

| Stage | Settings on the app target | Errors | Warnings | Files | Coverage |
| --- | --- | --- | --- | --- | --- |
| 1 · Baseline | as-is | 0 | 1 | 1 | 163/167 · full |
| 2 · Targeted | `SWIFT_STRICT_CONCURRENCY = targeted` | 0 | 1 | 1 | 163/167 · full |
| 3 · Complete | `SWIFT_STRICT_CONCURRENCY = complete` | 1 † | **19** | **14** | 163/167 · full |
| 4 · Complete + MainActor | stage 3 + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `NonisolatedNonsendingByDefault` | 1 † | **15** | **9** | 163/167 · full |
| 5 · Swift 6 mode | `SWIFT_VERSION = 6.0` | 4 | 9 | 7 | 142/167 · partial |
| 6 · Swift 6 + MainActor | stage 5 + `MainActor` + `NonisolatedNonsendingByDefault` | 13 | 0 | 4 | 142/167 · partial |

Stages 5 and 6 were each run twice, once plain and once with
`-continue-building-after-errors`. The table reports the run that reached the most files. The second
run of stage 5 reached only 103 files and reported 2 errors in 4 files; the second run of stage 6
reached 122 files and reported the same 13 errors. The counts move between runs because a parallel
Swift driver stops at a different point each time. **That instability is itself part of the finding:
an error-mode diagnostic count is not reproducible, and a warning-mode count is.** Stages 1 to 4
reported identical numbers on every run.

† The single error in stages 3 and 4 is a **toolchain bug**, not a project defect:
`Views/NotificationSettingsView.swift:64:10: error: failed to produce diagnostic for expression;
please submit a bug report`. The compiler can compile that expression, but it cannot render a
warning inside it. It appears only in warning mode, and it fails the build. Section 5 handles it.

**Stage 2 is a no-op.** `targeted` produces exactly the same single warning as the baseline.
It buys nothing here. Skip it.

**Stages 5 and 6 are lower bounds, and that is the finding.** In error mode the Swift module stops,
so files that depend on a failed file never compile and never report. Neither run reached more than
142 of 167 files, and `-continue-building-after-errors` did not help error mode at all — it made
coverage worse in one run and better in the other. **Error mode cannot produce a complete count
until the earlier errors are already fixed.** Stages 3 and 4,
which run at full coverage, are the only trustworthy totals. This is the strongest argument for
warnings-first, and it is measured rather than asserted.

**Stage 4 beats stage 3.** The brief's hypothesis holds: for this UI-heavy app, main-actor-by-default
plus `NonisolatedNonsendingByDefault` produces **fewer** diagnostics than plain `complete` — 15 in 9
files against 19 in 14 files — and it does so at equal, full coverage. It is not a free win, though:
it trades one problem set for another. See section 3.

### Test targets

Measured with `build-for-testing`, with the app target left at baseline so it could not stop the
build.

| Stage | Settings on the test targets | Errors | Warnings | Files |
| --- | --- | --- | --- | --- |
| T1 · Baseline | as-is | 0 | 1 | 1 |
| T2 · Complete, both test targets | `SWIFT_STRICT_CONCURRENCY = complete` | 0 | **1145** | 2 |
| T3 · Complete + MainActor, both test targets | T2 + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | 0 | **6** | 2 |
| T4 · Complete + MainActor, UI test target only | T3 scoped to `CatCareCalendarUITests` | 0 | **6** | 2 |

**1144 of the 1145 warnings in T2 come from one file**: `CatCareCalendarUITests/CriticalFlowsUITests.swift`
(1565 lines, one `final class CriticalFlowsUITests: XCTestCase`, 40 test methods). `XCUIApplication`
and its element APIs are main-actor-isolated, and XCTest methods are `nonisolated`, so every
`app.buttons[...]`, every tap, and every assertion reports.

**The 47 Swift Testing files under `CatCareCalendarTests/` produce zero warnings under `complete`.**
That is worth stating plainly: the modern test suite is already strict-concurrency clean. All of the
test-side work is in the one legacy XCTest UI file.

**One build setting removes 1144 of the 1145 warnings.** T4 shows the fix does not need to touch the
unit test target at all: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on `CatCareCalendarUITests`
alone gets the same 6. Scoping it to the UI test target is the better choice, because forcing
main-actor isolation on the Swift Testing target would serialise tests that currently run in
parallel, for no diagnostic benefit.

---

## 3. Diagnostic categories

### App target, stage 3 (`complete`, Swift 5 mode) — 19 warnings, 14 files

| # | Category | Warnings | Files | Effort |
| --- | --- | --- | --- | --- |
| A | Non-concurrency-safe `static` singleton | 5 | 5 | Mechanical |
| B | Main-actor UIKit call from a `nonisolated` synchronous context | 9 | 4 | Mechanical |
| C | Main-actor property read from a `nonisolated` context | 2 | 2 | Needs thought |
| D | Sending a non-`Sendable` value across an isolation boundary | 2 | 2 | Needs thought |
| E | Missing `import SwiftData` (pre-existing, not concurrency) | 1 | 1 | Mechanical, 1 line |
| F | Toolchain bug in a large SwiftUI expression | 1 error | 1 | Workaround needed |

**A · `static` singletons — mechanical, 5 files.** `Models/CareTaskTemplate.swift:174`
(`CareTaskTemplateManager.shared`), `Utilities/DownsampledImageLoader.swift:17`
(`NSCache<NSString, UIImage>`), `Utilities/NavigationRouter.swift:7`,
`Utilities/OnboardingManager.swift:6`, `Utilities/PhotoManager.swift:5`. Each reads
`static property 'shared' is not concurrency-safe because non-'Sendable' type 'X' may have shared
mutable state`. **These become hard errors in Swift 6 mode** — they are the 2–4 errors that stop
stages 5 and 6. The correct fix is `@MainActor` on the type, which matches what these types already
do (they are app-lifetime UI-facing state). `NavigationRouter` is already `@Observable`, and the repo
convention marks `@Observable` classes `@MainActor`, so this is annotating what is already true.
Do **not** reach for `nonisolated(unsafe)` here; it would hide the mutable state rather than protect
it. `DownsampledImageLoader`'s `NSCache` is the one member of this group that deserves a moment's
thought, because it is deliberately off the main actor for image work — `Mutex` (available on
iOS 18.4, see section 1) or moving the cache inside the existing `InFlightImageLoadCoordinator`
actor are both sound.

**B · Main-actor UIKit calls — mechanical, 4 files.** `Utilities/HapticsService.swift` lines 32, 53,
74 (6 warnings: `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`,
`UISelectionFeedbackGenerator` constructors and their fire methods),
`Utilities/Modifiers/DismissKeyboardModifier.swift:10` (`UIApplication.shared.sendAction`),
`Utilities/AppLaunchBootstrapper.swift:40` (`UIView.setAnimationsEnabled`),
`Utilities/CameraView.swift:69` (`UIImagePickerController.isSourceTypeAvailable`). All four call
main-actor UIKit from synchronous `nonisolated` code. Marking the enclosing method or type
`@MainActor` is correct and safe: every one of these call sites is already reached from the main
thread in practice, because they run from view code or from app launch.

**C · Main-actor property from `nonisolated` context — needs thought, 2 files.**
`Views/AddCaregiverView.swift:106` (`avatarImage`) and
`Utilities/Modifiers/DismissKeyboardModifier.swift:10` (`UIApplication.shared`). Small, but each
needs a look at which side of the boundary should move.

**D · Sending non-`Sendable` values — needs thought, 2 files.** These are the two places where the
compiler is pointing at a real boundary rather than a missing annotation.

- `Utilities/TaskAssistantCloudInterpreter.swift:51` — `sending value of non-Sendable type
  '[String : Any]' risks causing data races`. This is the cloud-function payload. `[String: Any]`
  is not `Sendable` because `Any` is not. The honest fix is a `Sendable` payload type (a `Codable`
  struct) rather than a dictionary, which also improves the call. A `sending` parameter is the
  smaller change if the dictionary is genuinely handed over and never touched again.
- `Views/Settings/SettingsDebugViews.swift:185` — `sending 'deliveredNotifications' risks causing
  data races`. `UNNotification` values crossing out of the notification-centre callback. This is
  debug-only UI, so the cost of getting it wrong is low, but the fix still deserves a real look
  rather than an annotation.

**E · `import SwiftData` — a genuine pre-existing bug, 1 line.** `Views/Cat/EnhancedCatCardView.swift:6`
uses `@Environment(\.modelContext)` while the file imports only `SwiftUI`. This warning is present
in the **baseline** build and in every stage. It has nothing to do with concurrency. It is the single
cheapest fix in this document, and it should be made regardless of what happens to the language mode.

**F · Toolchain bug — a workaround, not a fix.** `Views/NotificationSettingsView.swift:64:10:
error: failed to produce diagnostic for expression`. Line 64 begins
`private var notificationTogglesSection: some View`, a long `Section` body. The compiler type-checks
it but cannot render a warning inside it, and it reports that failure as an error, which fails the
build. Splitting that section into its own `View` struct — which `swift-style-guide` already asks for
("Do not break views up using computed properties; place them into new `View` structs instead") — is
very likely to clear it. This must be handled **before** `complete` can be turned on for the app
target, because it is the one thing that turns a warnings-only stage into a failed build.

### App target, stage 4 (`complete` + MainActor default) — 15 warnings, 9 files

Stage 4 removes categories A and B entirely: main-actor-by-default makes those singletons and those
UIKit calls correct with no annotation at all. In exchange it surfaces two new categories:

| # | Category | Warnings | Files | Effort |
| --- | --- | --- | --- | --- |
| G | SwiftData `@Model` member falls outside the main actor | 9 | 3 | **Needs thought** |
| H | `Shape` conformance crosses into main-actor code | 3 | 3 | Mechanical |
| C/D/E | as above | 3 | 3 | mixed |

**G · SwiftData `@Model` types — the real cost of stage 4, 3 files.** `Models/Cat.swift` lines 78,
99, 104 (×2), 112 (×2) — 6 warnings; `Models/CareTask.swift` lines 306, 374; and
`Models/TaskAssistantViewModel.swift:724`. Under main-actor-by-default the model types become
main-actor-isolated, but SwiftData reaches into them from its own contexts, so their computed
properties and static helpers (`Cat.displayName`, `Cat.validateAge`, `PhotoManager.absoluteURL(for:)`
read from `Cat`, `CareTask.localizedDataKey`, `DueDateText.text(dueDate:relativeTo:)`) start
reporting. **This is the category to think hardest about.** Marking these members `nonisolated` is
usually right — they are pure derivations from stored properties — but each one needs checking
against what it actually reads. Doing this carelessly is exactly the failure mode
`swift-concurrency-pro` warns against. This repo is local-first on SwiftData with 57 files importing
it, so this category is the one that could grow.

**H · `Shape` conformances — mechanical, 3 files.** `Views/Tasks/TaskAssistantMascotView.swift:113`
(`TaskAssistantMascotEar`), `:124` (`TaskAssistantMascotSmile`),
`Views/Tasks/TaskCalendarView.swift:584` (`RoundedCorner`). `conformance of 'X' to protocol 'Shape'
crosses into main actor-isolated code`. `Shape.path(in:)` must be callable off the main actor, and
main-actor-by-default put these structs on it. `nonisolated struct` on each of the three is the fix.
Three lines.

### Test targets

One category, one file, one setting. See section 2, T4.

### Where the work actually is

Combining the full-coverage measurements: **the migration is 19 app-target warnings in 14 files plus
6 test-target warnings in 2 files, once the UI test target's default isolation is set.** Roughly
two-thirds of the app-target work (categories A, B, E, H) is mechanical annotation of things that are
already true at runtime. The genuinely interesting work is category D (2 sites) and, only if you
choose stage 4, category G (9 sites in 3 SwiftData files). This is a small migration. It is not a
rewrite.

---

## 4. The `@concurrent` correction

**A previous analysis in another session recorded that `@concurrent` "does not exist" for this
project, and that `nonisolated(nonsending)` is unavailable at `SWIFT_VERSION = 5.0`. Both claims are
wrong.** The claim was reasoned from the build setting. The build setting does not decide this; the
compiler does, and the compiler is Swift 6.4.

Probed directly with `xcrun swiftc -sdk <iphonesimulator> -target arm64-apple-ios18.4-simulator
-typecheck`:

| Construct | Swift 5 mode, no flags | Swift 6 mode | Swift 5 + `NonisolatedNonsendingByDefault` |
| --- | --- | --- | --- |
| `@concurrent func f() async` | **accepted** | accepted | accepted |
| `nonisolated(nonsending) func f() async` | **accepted** | accepted | accepted |
| `@concurrent` on a `@MainActor` type's async method | accepted | — | — |
| `@concurrent` on a **non-async** func | rejected: `cannot use @concurrent on non-async instance method` | — | — |
| `nonisolated(nonsending)` on a **non-async** func | rejected: `cannot use 'nonisolated(nonsending)' on non-async instance method` | — | — |

What is actually true:

- **Both spellings are available to this project today**, at `SWIFT_VERSION = 5.0`, targeting
  iOS 18.4, with no upcoming-feature flag and no language-mode change. Neither carries an
  availability floor.
- **The only real constraint is that both require an `async` function.** That, not the language mode,
  is what rejects a `@concurrent` annotation.
- The language mode changes what `@concurrent` *means in contrast to the default*, not whether you
  may write it. In Swift 5 mode without `NonisolatedNonsendingByDefault`, a `nonisolated` async
  function already leaves the caller's actor, so `@concurrent` mostly restates the default and its
  value is documentary. Once `NonisolatedNonsendingByDefault` is on, plain `nonisolated` async stays
  on the caller's actor and `@concurrent` becomes the load-bearing way to say "leave it." That is a
  good reason to adopt the flag, and no reason at all to believe the attribute is absent.

**Practical consequence for the standing example.** `docs/swift-skill-recheck-file3-handoff.md:85-87`
and `docs/swift-skill-recheck-file4-handoff.md:49-50` both record that
`Models/TaskAssistantViewModel.swift`'s photo-save offload must keep `Task.detached` because
`@concurrent` is unavailable "at `SWIFT_VERSION = 5.0`," to be replaced "when the target moves to
Swift 6.2." That replacement is available now. `savePhotosToDocuments` at
`TaskAssistantViewModel.swift:710` is already `private nonisolated static func` — making it `async`
and `@concurrent`, and awaiting it, is a legitimate change today. It removes an unstructured
`Task.detached` and states the intent (offload CPU work) in the signature. It does not wait on this
migration.

---

## 5. Recommended staged path

The measurements confirm the shape the brief expected — warnings first, language mode last — and they
add one thing the brief did not anticipate: **the app target cannot go to warning mode until the
`NotificationSettingsView` toolchain bug is worked around.** That reorders the first two stages.

Each stage below is a stopping point. The project builds, and ships, at the end of every one.

### Stage 0 — the concrete first commit (measured, verified, zero collision risk)

Commit an `.xcconfig` that records the measured settings, plus this report. **Do not touch
`project.pbxproj` yet.** A branch is in flight in the main checkout on issue #16, and
`project.pbxproj` is a single-owner file: two branches editing it produce a merge conflict that is
tedious and easy to resolve wrongly. An `.xcconfig` is a new file. It conflicts with nothing.

This commit contains `Config/StrictConcurrency.xcconfig` and
`docs/swift6-concurrency-assessment.md`. It changes no build behavior until someone wires the
xcconfig up, which is a one-line change per configuration in Xcode's UI, made deliberately, after
issue #16 lands.

### Stage 1 — the UI test target (1 build setting, removes 1144 warnings)

Set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_STRICT_CONCURRENCY = complete` on
`CatCareCalendarUITests` only. **Verified: `** TEST BUILD SUCCEEDED **`, 1145 warnings → 6.**
Then fix the 5 remaining override-isolation warnings in `CriticalFlowsUITests.swift` (`init()`,
`init(invocation:)`, `init(selector:)`, `setUpWithError()`, `tearDownWithError()` — each needs its
isolation reconciled with the `nonisolated` `XCTestCase` declaration it overrides). Leave
`CatCareCalendarTests` alone: it is already clean under `complete`, and forcing main-actor isolation
on it would serialise a parallel Swift Testing suite for no benefit.

This stage is the best value in the whole migration: one setting, one file, about 99.5% of the
test-side diagnostics gone. Run the CI-parity UI test pass (iPhone 12 / iOS 18.5 and iOS 26.5,
sequentially, `-disable-concurrent-destination-testing`) to confirm the tests still pass, because
`@MainActor` changes when the test bodies run.

### Stage 2 — clear the two blockers in the app target (2 files)

1. Split `notificationTogglesSection` out of `Views/NotificationSettingsView.swift` into its own
   `View` struct. This is what `swift-style-guide` asks for anyway, and it should clear the
   `failed to produce diagnostic for expression` error. **Verify by re-running stage 3 and
   confirming 19 warnings and 0 errors.** If it does not clear, the fallback is to keep the app
   target at `targeted` while the rest proceeds, and to file the compiler bug.
2. Add `import SwiftData` to `Views/Cat/EnhancedCatCardView.swift`. One line, present in the
   baseline, unrelated to concurrency.

### Stage 3 — app target to warning mode

Set `SWIFT_STRICT_CONCURRENCY = complete` on the app target, still at `SWIFT_VERSION = 5.0`.
Expected: **19 warnings in 14 files, 0 errors, full coverage, build succeeds.** The project ships
with these warnings for as long as it needs to. This is the stage that can sit alongside feature
work indefinitely, because it never breaks a build.

### Stage 4 — fix the warnings, in category order, smallest first

Category E (1 line, already done in stage 2) → H (3 lines) → B (4 files) → A (5 files) → C (2 files)
→ D (2 files). Each category is a separate small commit. Re-measure after each; the count only goes
down. Category D is the only one that needs design work, and it is 2 sites.

### Stage 5 — decide on default actor isolation, on evidence

Only now is this a real decision, because by stage 5 you know the codebase. Stage 4 of the
measurement says main-actor-by-default is cheaper up front (15 warnings against 19, 9 files against
14) and better matched to a UI-heavy local-first app. But it moves the cost into the SwiftData models
(category G, 9 sites in 3 files), which is the part of this codebase that most deserves care. Measure
it again at that point — the numbers will have moved — and choose then. Do not decide it now.

### Stage 6 — flip `SWIFT_VERSION` to 6.0

Last, and only once stage 3 reports 0 warnings. At that point the flip is mechanical, because every
diagnostic that Swift 6 mode would raise to an error has already been seen and fixed as a warning.
Set it on all 6 build configurations. Expect this stage to be uneventful; if it is not, stage 3 was
not finished.

#### Stage 6 is blocked today by 2 `#Predicate` macro warnings

Measured 2026-09-09 on this branch, at its current settings, with a clean build
(`clean build`, iPhone 12 / iOS 18.5, own `-derivedDataPath`): **`** BUILD SUCCEEDED **`, 0 errors,
0 warnings from any file inside the repository — and 2 warnings that carry no repository path:**

```
macro expansion #Predicate:5:22: warning: type 'KeyPath<CareTask, UUID>' does not conform to the 'Sendable' protocol; this is an error in the Swift 6 language mode
macro expansion #Predicate:5:22: warning: type 'KeyPath<CareTaskCompletion, Date>' does not conform to the 'Sendable' protocol; this is an error in the Swift 6 language mode
```

Both come from Foundation's `#Predicate` expansion, so their diagnostic location is the macro, not a
source file. A path-scoped warning count therefore reports 0 and misses them. The two call sites are:

| Call site | Key path | Reported type |
| --------- | -------- | ------------- |
| `Utilities/TaskActionService.swift:111` | `\.id` | `KeyPath<CareTask, UUID>` |
| `Views/SettingsView.swift:36` | `\.completedAt` | `KeyPath<CareTaskCompletion, Date>` |

Each warning says "this is an error in the Swift 6 language mode". The stage 6 gate above is
"only once stage 3 reports 0 warnings", so **the gate is not met**. Resolve these 2 first, or
confirm on the shipping toolchain that they do not become errors. Do not read the branch headline
"0 warnings" as clearance for stage 6; count macro-expansion diagnostics separately.

### Why not the other order

Flipping `SWIFT_VERSION = 6.0` first is measurably worse, and this is the measurement that shows it:
stages 5 and 6 never reached more than 142 of 167 files, and their coverage changed between runs.
**In error mode you cannot even see the size of the problem**, because each failure hides the files
behind it. You would fix a handful of errors, get
a new set, and never know how far along you were. Warning mode reported all 19 problems in 14 files
on the first run, at full coverage. Measure in warning mode; commit in warning mode; flip once.

---

## 6. Downsides and risks

**1 · The annotation-spray failure mode is the real danger, and this migration has a specific
exposure to it.** `swift-concurrency-pro` is explicit: never use `@unchecked Sendable` to silence a
diagnostic, and do not reach for `nonisolated(unsafe)`. The exposure here is concrete rather than
theoretical:

- Category A's 5 singleton diagnostics can each be silenced with `nonisolated(unsafe)`. That would
  produce a green build and hide 5 pieces of genuinely shared mutable state. `@MainActor` is the
  correct fix for 4 of the 5, and the fifth (`DownsampledImageLoader`'s `NSCache`) needs a real
  choice between `Mutex` and the existing actor.
- Category D's 2 diagnostics are the two places the compiler has found something true. Making
  `[String: Any]` `Sendable` by fiat is precisely the wrong move; a `Codable` payload type is the
  right one.
- Category G (9 sites, only if stage 5 chooses main-actor-by-default) is the largest spray risk,
  because `nonisolated` on a SwiftData `@Model` member looks harmless and is not always correct.
- The codebase currently holds exactly **one** `@unchecked Sendable` (`DownsampledImageLoader.swift:87`,
  a private `ImageResult` inside an actor — a defensible use) and **one** `@preconcurrency`
  (`NotificationManager.swift:677`, `UNUserNotificationCenterDelegate`). That is a clean starting
  point. It is worth protecting: grep for both after each stage, and require a written reason for any
  new one.

**2 · Collision with in-flight branches.** `project.pbxproj` is the collision point. Every stage
except stage 0 and stage 4 changes it. A branch is currently open on issue #16 in the main checkout.
Two branches that both edit `project.pbxproj` conflict, and pbxproj conflicts are resolved by hand
in a format that gives no help when you get it wrong. Mitigation: stage 0 commits no pbxproj change
at all; land each later stage as its own small PR, at a quiet moment, and never in parallel with
another pbxproj-touching branch. Stage 4's per-category commits touch only `.swift` files and are
safe to interleave.

**3 · Stage 1 changes when test code runs.** Adding `@MainActor` semantics to
`CriticalFlowsUITests` is not a no-op at runtime. 40 test methods change isolation. The build
succeeds, which is what was measured; that the tests still *pass* was not measured, and it must be
confirmed with the sequential dual-destination CI-parity run before the stage lands.

**4 · One measurement rests on a toolchain bug being fixable.** Stage 3's whole premise is that the
app target can sit in warning mode without failing the build. Today it fails, on
`NotificationSettingsView.swift:64`, because of a compiler defect. The proposed workaround (extract
the section into a `View` struct) is well motivated and likely to work, but it is **unverified** —
to verify it you must make the edit, which is outside this pass. If it does not work, stage 3 becomes
"the app target stays at `targeted` and gains nothing," and the migration has to proceed by fixing
categories blind, in error mode, with the poor visibility that section 5 describes. This is the
single biggest unknown in the plan, and it is cheap to resolve: one edit, one 40-second build.

**5 · Xcode 27 / Swift 6.4 is a beta toolchain.** The measurements come from
`/Applications/Xcode-beta.app`. Diagnostic counts can move between betas, and the
`failed to produce diagnostic` bug may vanish or be replaced by another. Re-measure on the release
toolchain before you treat any count here as final. The method is scripted (Appendix A), so a re-run
is cheap.

**6 · The vendor-SDK interaction is a live trap.** Section 1 records that a *global*
`SWIFT_STRICT_CONCURRENCY=complete` crashes the compiler on the `FirebaseAuth` target. Anyone who
tries to measure or migrate by putting the setting on the `xcodebuild` command line — the natural
first instinct, and what the brief suggested — will hit a compiler crash in vendor code and
reasonably conclude the migration is blocked. It is not. The setting simply must be target-scoped.

**7 · What was not measured.** The 4 app `.swift` files outside the compile sources; the app target
under `SWIFT_VERSION = 6.0` at full coverage (impossible, see section 2); Release-configuration
builds (all measurements are Debug); whether the test *suites* pass under any stage; and the
`CatCareCalendarTests` target under Swift 6 *mode* rather than `complete` warnings.

---

## Appendix A — measurement method

Reproducible, and scripted rather than hand-run, so the numbers can be re-derived on a release
toolchain.

1. **Scope the setting to a target, not the command line.** A Python patcher edits only the
   `XCBuildConfiguration` blocks matching a given `PRODUCT_BUNDLE_IDENTIFIER`, and inserts the
   stage's settings in place of that block's `SWIFT_VERSION` line. `git checkout -- project.pbxproj`
   restores the file after every stage. The worktree was verified clean (`git status --short` and
   `git diff --stat` both empty) after the last stage.
2. **Force a full recompile of the app target only.** `rm -rf
   <dd>/Build/Intermediates.noindex/CatCareCalendar.build` before each stage, with no `clean`, so
   the vendor-SDK artifacts survive. A stage costs about 40 s instead of about 10 min. This mattered:
   the first attempt at stage 2 changed the setting without clearing the intermediates, Xcode
   rebuilt nothing, and the stage reported 0 diagnostics — a false result that a plain incremental
   build produces silently.
3. **Build compile-only, with no simulator.** `-destination 'generic/platform=iOS Simulator'`.
   No simulator was booted at any point in this assessment, so the one-simulator constraint was
   never in play.
4. **Try to push error-mode coverage further.** `OTHER_SWIFT_FLAGS = "$(inherited)
   -continue-building-after-errors"`. It helped the *warning* stages (it took the MainActor warning
   stage from 143 files to the full 163) but it did **not** help error mode: stage 5 fell from 142
   files to 103 with the flag, and stage 6 rose from 142 to only 122. Error mode stayed incomplete
   either way, and its coverage was not reproducible between runs.
5. **Count honestly.** Extract `^<worktree>/....swift:LINE:COL: (error|warning): msg`, `sort -u`
   to remove the duplicates that a parallel Swift driver emits, then group by file and by message
   shape (string literals replaced with `'X'`). Diagnostics whose path is outside the worktree — the
   vendor SDK, the platform SDK — are counted separately, and they were **zero** in every stage.
   Coverage is the count of distinct app-target `.swift` paths that appear in the log, which is what
   exposed stages 5 and 6 as lower bounds.

Stage logs, deduplicated diagnostic lists, and the patcher and runner scripts are in this session's
scratchpad. They are not committed, because they are machine-specific and toolchain-specific.

---

## Appendix B — documentation drift, for the docs pane

**Not this assessment's task to fix.** Listed for whoever owns the documentation pass. These lines
are factually wrong about Swift versions, concurrency, or dependencies. `CLAUDE.md` is that pane's
file to own, and this branch does not touch it.

### Wrong: "no third-party dependencies"

The project depends on the Google `firebase-ios-sdk` package (`upToNextMajorVersion` from 11.7.0),
four products, two importing files. See section 1.

| File | Line | Wrong text |
| --- | --- | --- |
| `CLAUDE.md` | 31 | "and has no third-party dependencies" (Project Overview) |
| `docs/architecture-review.md` | 3 | "SwiftUI + SwiftData, iOS 18.4+, no third-party dependencies" |
| `.cursor/rules/general-swiftui.mdc` | 21 | "Do not introduce third-party dependencies without approval" — still good policy, but it reads as though none exist |

`CLAUDE.md`'s architecture section also describes no cloud layer, while
`Utilities/FirebaseBootstrapper.swift` and `Utilities/TaskAssistantCloudInterpreter.swift` exist and
the task assistant has a cloud path.

### Wrong: `@concurrent` and `nonisolated(nonsending)` are unavailable

Both are available today at `SWIFT_VERSION = 5.0` on iOS 18.4. See section 4.

| File | Line | Wrong text |
| --- | --- | --- |
| `docs/swift-skill-recheck-file3-handoff.md` | 85-87 | "`@concurrent` is the Swift 6.2 answer and is unavailable at `SWIFT_VERSION = 5.0`… When the target moves to Swift 6.2, replace it." |
| `docs/swift-skill-recheck-file4-handoff.md` | 49-50 | "`@concurrent` is the standing example" of an unreachable API |
| `docs/swift-skill-recheck-summary.md` | 156 | "`@concurrent` is the Swift 6.2 answer for file 3's photo-save offload" — the conclusion is right, the implied unavailability is not |

### Imprecise: the version-gap framing

These lines are not false, but they conflate the *language mode* setting with the *toolchain*, which
is what produced the `@concurrent` error. The distinction worth writing down is this:
`SWIFT_VERSION = 5.0` constrains language-mode semantics and strictness; it does not constrain which
syntax the Swift 6.4 compiler accepts. Availability, separately, comes from
`IPHONEOS_DEPLOYMENT_TARGET = 18.4` — and that one does genuinely rule out `Task.immediate`,
`InlineArray`, and `withTaskPriorityEscalationHandler` (section 1).

| File | Line |
| --- | --- |
| `CLAUDE.md` | 135 (reconciliation note) |
| `.cursor/rules/general-swiftui.mdc` | 13 |
| `docs/swift-skill-recheck-handoff.md` | 54 |
| `docs/swift-skill-recheck-file2-handoff.md` | 46 |
| `docs/swift-skill-recheck-file3-handoff.md` | 44-45 |
| `docs/swift-skill-recheck-file4-handoff.md` | 49 |
| `docs/swift-skill-recheck-summary.md` | 7 |
| `docs/swift-skill-trigger-setup.md` | 208 |

### Also worth recording

`CLAUDE.md:98` says `@Observable` classes are "`@MainActor` by default." That is the repo's
convention, not the compiler's behavior: `SWIFT_DEFAULT_ACTOR_ISOLATION` is unset, so nothing is
`@MainActor` by default. Category A's 5 diagnostics were the direct evidence — at the time of the
assessment `NavigationRouter` was `@Observable` and *not* main-actor-isolated, which is why it
reported.

This branch changed that: `NavigationRouter` is now `@MainActor @Observable`, with
`nonisolated static let shared` and `nonisolated init()` so the `@Entry` environment default still
resolves. `SWIFT_DEFAULT_ACTOR_ISOLATION` remains unset, so the convention point above still holds;
only the counter-example is gone.

### Before you merge this branch — documentation that goes stale on merge

`NavigationRouter` is no longer a valid example of an un-isolated `@Observable` type. Two lines on
`docs/reconcile-agent-docs` cite it as exactly that, and both become false as soon as that branch
and this one are both on `main`. Whoever merges second must fix them in the same merge:

| File | Line at time of writing | Claim to replace |
| ---- | ----------------------- | ---------------- |
| `CLAUDE.md` | 135 | "`NavigationRouter` is the live counter-example — it is `@Observable` and carries no `@MainActor`" |
| `.claude/rules/swift-skills.md` | 65 | "`NavigationRouter` is `@Observable` with no `@MainActor`. Read the source before you assume." |

Neither line is wrong on its own branch today, so do not pre-edit them; a pre-edit only moves the
falsehood to the other side. Keep the surrounding point — `SWIFT_DEFAULT_ACTOR_ISOLATION` is unset,
so read the source instead of assuming isolation — and drop or replace the `NavigationRouter`
example. `docs/agents/doc-audit-2026-09.md:87` carries the same claim as an audit row; update it for
consistency.
