# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` is a copy of this file for Codex. Edit `CLAUDE.md`, then copy it to `AGENTS.md`.

Read `STATUS.md` (open PRs, next step, what waits for the owner) at session start; update it before the final report.

**Safe merges.** The owner (2026-11-11) keeps routine PRs off their list. Once CI is green and GitHub
shows the PR `MERGEABLE`, an agent squash-merges these itself and deletes the branch (main requires an up-to-date branch: when
GitHub says it is behind, run `gh pr update-branch` and wait for the new CI): docs-only PRs
(Markdown and `docs/` only), including `STATUS.md` updates, and Dependabot patch and minor bumps. App
code, config, a major bump and every Cloud Function change still wait for the owner. A merged bump in
the functions folder still needs a deploy, and the deploy needs the owner's yes: ask once, in the same
message that reports the merges. Record each merge in `STATUS.md` in the same session.

## Swift skills are mandatory

Before you write or edit a Swift file under `Purrtine/`, `PurrtineTests/`, or `PurrtineUITests/`, invoke
each matching skill from the routing table in `.claude/rules/swift-skills.md`, then edit. This applies to
one-line changes too: a small change to a `body` or an `async` call is where these skills catch the most
problems. Run the same skills again over the finished change before you end the turn; a `PostToolUse` hook
names them for you. The same file holds the `Backport` rule for iOS 26/27 API, the version reconciliation
for the `swift-style-guide` skill, and the paths that hook cannot reach.

## Path rules

Each file in `.claude/rules/` holds the binding rules for one kind of file. Claude Code loads a rule file
when it reads a matching file. An agent that does not load `.claude/rules/` (Codex) reads the rule file
itself before it touches a matching path. A reviewer reads every rule file that matches the change.

| Rule file              | Read before you touch                               | Holds                                                                  |
| ---------------------- | --------------------------------------------------- | ---------------------------------------------------------------------- |
| `swift-skills.md`      | Any Swift file                                      | Skill routing table, `Backport`, version reconciliation, the hook      |
| `swift-conventions.md` | Any Swift file                                      | Coding conventions: naming, state, navigation, concurrency, errors     |
| `notifications.md`     | Swift in `Purrtine/` or `PurrtineTests/`            | `NotificationManager`, `CareTaskWriting`, reminder resync, catch order |
| `swiftdata.md`         | Swift in `Purrtine/` or `PurrtineTests/`            | `@Query` use, relationships, schema versions and migration             |
| `localization.md`      | Swift in those two folders, `Localizable.xcstrings` | String Catalog keys, generated symbols, en + tr parity                 |
| `accessibility.md`     | `Purrtine/Views/`, `PurrtineUITests/`               | Accessible names, Dynamic Type, touch targets                          |
| `testing.md`           | `PurrtineTests/`, `PurrtineUITests/`                | Swift Testing, test support fakes, schema baseline                     |

## Project Overview

Purrtine is a local-first iOS app (SwiftUI + SwiftData) for cat owners to manage care routines, recurring tasks, and history across multiple cats. It targets iOS 18.4+ and uses Swift 6-style patterns (project file now reports `SWIFT_VERSION = 6.0`, verified 2026-09-24 against `project.pbxproj`, all configurations and targets). See "Version reconciliation" in `.claude/rules/swift-skills.md` before applying the `swift-style-guide` skill's iOS 26/Swift 6.2 version claims literally.

### Dependencies

The app is local-first, but it is **not dependency-free**. Verified 2026-09-08:

- One Swift package: `firebase-ios-sdk` (`https://github.com/firebase/firebase-ios-sdk`, `upToNextMajorVersion` from `11.7.0`). Four products are linked into the app target: `FirebaseCore`, `FirebaseAuth`, `FirebaseAppCheck`, `FirebaseFunctions`.
- Two app-target files import it: `Utilities/FirebaseBootstrapper.swift` and `Utilities/TaskAssistantCloudInterpreter.swift`.
- Recount with `grep -o 'repositoryURL = [^;]*' Purrtine.xcodeproj/project.pbxproj | sort -u`.

Two consequences an agent must respect:

- **Never set `SWIFT_STRICT_CONCURRENCY = complete` project-wide.** It crashes the compiler on the `FirebaseAuth` target. `docs/swift6-concurrency-assessment.md` and `Config/StrictConcurrency.xcconfig` hold the measured per-file plan instead.
- `Package.resolved` **is tracked in git**, pinning the vendor SDK version so every checkout resolves the same one. Adding another file under `project.xcworkspace/` needs the same trick, so know why: `*.xcworkspace` at `.gitignore:4` ignores the whole **directory**, and git never descends into an ignored directory, so `git add` on a path inside it silently does nothing and a lone `!…/Package.resolved` cannot rescue it. Every parent directory on the path carries its own negating rule (`.gitignore:12-15`). Re-verify with `git check-ignore -v Purrtine.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — it prints nothing today.

## Build & Test Commands

```bash
# Open in Xcode (preferred for day-to-day work)
open Purrtine.xcodeproj

# Build from CLI
Scripts/xcb.sh build

# Local loop: the unit scheme (no UI test build, no coverage), only the suites you touched;
# --only takes a Swift Testing suite or test name and is repeatable
Scripts/xcb.sh test --scheme PurrtineTests --only PurrtineTests/TaskActionServiceTests

# This project's SimSlim devices (template, test device, verify slots)
Scripts/slim-sim.sh names
Scripts/slim-sim.sh slots
```

- **Verify trial** (owner, 2026-10-14). UI tests, the `-ui-testing` launch mode, simulator checks, and iOS-version passes are paused while the owner tries the verification skill. Prove what a user sees with `verify-purrtine` (`.claude/skills/verify-purrtine/`). Run the check through the `sim-verifier` subagent (`~/.claude/agents/sim-verifier.md`, user-level: a fresh clone or Codex has no such agent, so drive the skill yourself there): name `verify-purrtine`, the feature files and the language in its prompt. It returns PASS, FAIL, BLOCKED or NEEDS OWNER YES with evidence paths; on NEEDS OWNER YES ask the owner, then continue the same subagent with the answers. You attach the key screenshots to the PR. The paused rules are parked outside the repo at `~/.claude/parked/2026-10-14-verify-trial/`; they do not apply during the trial. A photo pick stays "not checked by hand" during the Verify trial: the system picker runs out of process, and the verify skill launches with no flags. The DEBUG-only `-inject-test-photo[=rotated|large|heic]` launch flag (#52; needs `-ui-testing`) is for the UI-test harness only: it makes "choose from library" on Add/Edit Cat, Add Caregiver and Task Completion feed a generated photo into the same loading code. UI tests that use it wait until the Verify trial ends (#94). Release builds have no such flag.
- Host toolchain as of 2026-09-08: **Xcode 27.0** (build `27A5194q`), **Swift 6.4**. The project's `SWIFT_VERSION = 6.0` (verified 2026-09-24) selects the language mode; it does not limit which syntax this compiler accepts. See "Version reconciliation" in `.claude/rules/swift-skills.md`.
- **Local tests: only what changed** (owner rule, 2026-10-11; the user-level `~/.claude/CLAUDE.md` carries the same rule). Locally, run the tests you added or changed plus the suites of the files you changed, each with `--only`. The full scheme stays a CI job: `.github/workflows/ci.yml` runs every unit test with coverage on each PR, and its result is the gate. The jobs skip themselves on a private repo, and a run whose jobs all skip still shows "success" (header comment of `ci.yml`); the repo is public (verified 2026-10-12), so the jobs run. CI runs the UI tests too, in the separate `ui-tests` job on one iOS runtime, the one that matches the runner's simulator SDK (#48; the `app` job still skips them with `-skip-testing:PurrtineUITests`). On a PR the job runs only when the PR changes `Purrtine/**`, `PurrtineUITests/**`, `*.xcodeproj/**` or `.github/workflows/**`; a docs-only PR skips it, and every push to main and every manual run runs it. Locally, run only the UI tests you added or changed, on each simulator the task names. List the tests you ran in the PR body.
- Agents build and test through `Scripts/xcb.sh`, never a bare `xcodebuild`. The script holds a machine-wide lock, so builds from every worktree and from TTB queue one at a time on this 16GB Mac; it shares one DerivedData and package checkout across worktrees, so Firebase compiles once. It writes the full log to a file and prints only errors, failures, and the tail. A run can wait minutes for the lock: give it a long Bash timeout or run it in the background. `Scripts/xcb.sh --help` lists the options.
- `Scripts/xcb.sh` and `Scripts/slim-sim.sh` are shared with TTB; keep each pair identical. `Scripts/simslim-profile.json` is this project's own.
- **Simulators** (owner, 2026-10-27). Every simulator here is an iPhone 12 / iOS 27.0 slimmed by SimSlim with `Scripts/simslim-profile.json` (all background services off except `photos` and `siri`; Purrtine needs the photo picker and speech recognition). `Scripts/slim-sim.sh` makes them: a pristine template `iPhone 12 slim tmpl (Purrtine)` that nobody boots or installs on; a persistent test device `iPhone 12 slim test (Purrtine)` that `Scripts/xcb.sh` builds and tests on by default (made from the template on first use; xcb shuts it down after a test that booted it and never shuts down any other simulator); and one `verify-purrtine-*` clone per verify run. At most `SLIM_SIM_MAX` verify clones run at once across Purrtine and TriQ (default 2). The shared stock `iPhone 12 (iOS 27)` is no longer used by these scripts. A feature that needs a disabled category (iCloud, Contacts, push) needs that category added to the profile in a PR.
- Two schemes. `PurrtineTests` (plan `PurrtineUnitTests.xctestplan`) is the inner loop: it builds the app and the unit test bundle only, skips the UI test target, and collects no coverage. `Purrtine` (plan `Purrtine.xctestplan`) is the full run with UI tests and coverage, and the only scheme that archives. CI (`.github/workflows/ci.yml`) runs this scheme without the UI tests in the `app` job (the `ui-tests` job runs them) and feeds its result bundle to `Scripts/check_coverage.sh`, which fails on a unit-scheme bundle because that has no coverage; the coverage bundle therefore comes from CI, not from a local run. Both plans set `CATCARE_UNIT_TESTING=1` — keep it when you edit either plan.
- When work is split across subagents: only one of them may build, run, or test on a simulator at a time, and xcodebuildmcp session defaults do not reach subagents — pass `simulatorId` and `bundleId` in the prompt. `Localizable.xcstrings`, `project.pbxproj`, `Theme.swift`, `CatCardStyle.swift`, and `NavigationRouter.swift` are single-owner files: subagents report the changes they need, and the coordinating agent applies them (then runs `LocalizationParityTests` after catalog edits).
- **Memory footprint.** Measure the running app with `vmmap --summary <pid> | grep "Physical footprint"` (find the pid via `pgrep -f "Purrtine.app/Purrtine"`).

## Architecture

### App entry & shared state
- `Purrtine/PurrtineApp.swift` is the app entry point. On launch it: builds the `ModelContainer` via `AppLaunchBootstrapper`, ensures a default `Caregiver` exists synchronously (`CaregiverBootstrapper`) to avoid race conditions on first task creation, seeds initial data if needed, and wires a `NotificationActionCoordinator` into `NotificationManager.shared`.
- Environment-based DI: `NavigationRouter.shared`, a `HapticsService`, and the SwiftData `modelContainer` are injected via `.environment(\.navigationRouter, ...)` / `.environment(\.haptics, ...)` using `@Entry`-style environment values — not `EnvironmentObject`.
- `NavigationRouter` (`Utilities/NavigationRouter.swift`) is an `@Observable` singleton owning `NavigationPath`, selected tab, and one-shot navigation flags (`shouldNavigateToMyCats`, `shouldNavigateToHistory`, `shouldTriggerAddTask`) consumed and then reset by the receiving view — this is the single entry point for cross-tab/deep-link navigation (see `AppRoute`/`handle(_:)`). `AppTab` (`ContentView.swift`) has four cases: `home`, `tasks`, `assistant`, `settings`.

### Cloud tier (optional, vendor-backed)

The app is local-first, and everything above works with no network. One feature reaches a server: the task assistant's fallback interpreter.

- `Utilities/FirebaseBootstrapper.swift` (`@MainActor enum`) does nothing at launch: the throwing `ensureSignedInAnonymously()` configures the SDK (App Check starts then and contacts Apple and Google) and signs in anonymously, on the first cloud interpreter call after consent, through the adapter's `signIn` closure (#12). It throws `cloudServicesDisabled` under UI tests, unit tests and previews. It reads `GoogleService-Info.plist` itself rather than calling a bare `FirebaseApp.configure()`, because that plist is gitignored and a bare configure hard-aborts the app when the file is absent. A checkout without the plist therefore launches normally with the cloud tier disabled.
- `Utilities/TaskAssistantCloudInterpreter.swift` declares the `@MainActor protocol TaskAssistantCloudInterpreting` and the `FirebaseTaskAssistantCloudInterpreter` adapter that calls the `interpretTaskAssistantRequest` Cloud Function. `TaskAssistantViewModel` takes it as an optional injected dependency; tests inject `FakeTaskAssistantCloudInterpreter` from `PurrtineTests/TestSupport/`.
- The protocol is main-actor isolated on purpose: its methods take `[CareTask]`, which are SwiftData models. Do not make it `nonisolated`.

### Feature organization
- `Models/`: the five SwiftData `@Model` types — `Cat`, `CareTask`, `CareTaskSchedule`, `CareTaskCompletion`, `Caregiver` (verified 2026-09-08; recount with `grep -rn -A2 '^@Model' --include='*.swift' Purrtine`). Only `Cat` sits in its own file: the other four are declared in `Models/CareTask.swift`, which is a known exception to the one-type-per-file convention in `.claude/rules/swift-conventions.md`. `CareTaskTemplate` and `RepeatConfiguration` are **not** persistent models — both are plain `struct`s, so `swiftdata-pro` rules do not govern them. The folder also holds `@Observable` view models (`TaskManagementViewModel`, `TaskAssistantViewModel`) and pure "presentation" structs that derive display-ready data from models (`TaskListPresentation`, `HistoryPresentation`, `HomeRoutineStatusPresentation`, `TaskCalendarPresentation`, `NotificationSettingsPresentation`). These presentation types are the seam most business-logic tests target directly (see the parallel files in `PurrtineTests/Models/`).
- Views stay thin; they read `@Query`/`ModelContext` and delegate to models/services.
- **Bulk task edit is not a feature of this app.** There is no multi-select mode and no production entry point that presents one. This is a product decision, recorded in `docs/adr/0001-no-bulk-task-edit.md` — do not propose the feature. Older documents in `docs/` that describe bulk editing as live describe orphaned code, not a screen a user can reach.
- `Style/Theme.swift` and `Style/CatCardStyle.swift` hold shared visual constants — use these instead of hardcoded colors/fonts.
- `Resources/Localizable.xcstrings` is the single String Catalog holding all localized strings (en + tr); every key must be translated in every locale (see `.claude/rules/localization.md`).
- `documentation/PRD.md` is the source of truth for product scope and success metrics; `documentation/features/` has per-flow specs; `documentation/changelogs/` holds dated change notes — add a dated file there for a substantial change. There is no root `CHANGELOG.md` in this repo.

---

## Agent skills

### Matt Pocock skills

Matt Pocock's 27 skills (`implement`, `code-review`, `tdd`, `grilling`, …) are project skills in
`.claude/skills/`, copied there by `npx skills` and pinned in `skills-lock.json` (2026-10-11,
v1.3.1). Call them by bare name: `/implement`, not `/mattpocock-skills:implement`. The old
`mattpocock-skills` plugin is turned off for this repo in `.claude/settings.json`, so each skill
loads once. Matt's `code-review` replaces the built-in `/code-review` in this repo, and
`implement` calls it by that name. Update with `npx skills@latest update -p`, then review the diff.
Add one with `npx skills@latest add mattpocock/skills -a claude-code --copy -y -s <name> <name>`:
names are space-separated; a comma-separated list installs nothing and prints no error.

### Issue tracker

Issues live as GitHub issues in `bckizildemir/Purrtine`, managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, used verbatim as label strings. All five exist in the tracker as of 2026-09-09. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Coordinator and session briefs

Read `docs/agents/coordinator.md` when you coordinate a batch: start implement sessions, review their
PRs, or merge them. Start each session from `docs/agents/implement-session-prompt.md`; review each PR
with `docs/agents/pr-review-brief.md`.

### Documentation audits

`docs/agents/doc-audit-2026-09.md` is the claim-by-claim audit of this file and the rest of the agent-facing docs, dated 2026-09-08. It records what was verified, what was false, and the six items that need a human decision. Two habits it asks of you:

- Every count in these documents carries the date it was measured. Trust the date, not the number — five of seven counts drifted in six weeks. Re-measure before you quote one.
- Verify an **absolute** claim before you rely on it ("all X goes through Y", "no dependencies", "API Z is unavailable"). Those are the claims that read as permission to skip a check, and every one this audit tested was wrong.
