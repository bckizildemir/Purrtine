# Handoff — file 2 of the Swift skill recheck: `Models/CareTask.swift`

**Written:** 2026-08-14 · **Scope:** one review pass over one file · **Run this at medium effort.**

> **CLOSED — status re-checked 2026-09-08.** The five-file pass finished on 2026-08-14 and every file
> was reviewed and fixed. This document is kept as a record of the brief, not as work to pick up.
> Do not act on the "Your job" and "Not started" rows below: they describe the mid-pass state of
> 2026-08-14. The closing summary is `docs/swift-skill-recheck-summary.md`. Everything under this
> banner is the original brief, corrections marked in place.

## Where this sits

This continues `docs/swift-skill-recheck-handoff.md`. Read that document first. It explains why the
pass exists and it lists all five files. Do not repeat its evidence work.

> ~~**That document is not on this branch.**~~ **Resolved 2026-09-08.** Both
> `docs/swift-skill-recheck-handoff.md` and the **Swift review skills** route table in `CLAUDE.md`
> are on `main` now. Read them from `main`; branch `fix/remove-orphan-cats-selection-done` no longer
> matters here.

Status of the five files:

| # | File (under `CatCareCalendar/`) | Skills | State |
| --- | --- | --- | --- |
| 1 | `Views/Tasks/TaskAddView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | Reviewed **and fixed** on 2026-08-14 |
| 2 | `Models/CareTask.swift` | `swiftdata-pro` | **Your job** |
| 3 | `Models/TaskAssistantViewModel.swift` | `swiftdata-pro`, `swift-concurrency-pro` | Not started |
| 4 | `Utilities/NotificationManager.swift` | `swift-concurrency-pro` | Not started |
| 5 | `Views/Tasks/TaskEditView.swift` | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` | Not started |

## Your job

Run `swiftui-pro`'s sibling skill **`swiftdata-pro`** over `CatCareCalendar/Models/CareTask.swift`
(749 lines). That is the only skill the routing table assigns to this file. The routing was verified
against these exact files on 2026-08-14. Trust it; do not re-derive it.

**Report first, then fix.** File 1 ran as report-then-fix, and the user asked for the fixes in the
same turn. Expect the same here: produce the grouped report, then wait for the go-ahead before you
edit, unless the user already told you to fix.

## Rules for the pass

- **Group findings by severity.** Real problems only. The skill body says "Report only genuine
  problems - do not nitpick or invent issues." Honour that.
- **Reconcile against this repo's reality.** `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and
  `SWIFT_VERSION = 5.0`. A finding that assumes iOS 26 or Swift 6.2 is not actionable here. Flag the
  gap; do not report the iOS 26 API as the fix. **Correction, 2026-09-08:** read `SWIFT_VERSION` as
  the language mode only. Swift 6.2 *syntax* compiles here on the Swift 6.4 toolchain; the 18.4
  deployment target is what limits iOS 26 *APIs*. See the reconciliation notes in `CLAUDE.md`.
- **CloudKit rules do not apply unless you prove they do.** The `swiftdata-pro` skill has a
  CloudKit section (no `@Attribute(.unique)`, optional relationships, default values). Check the
  `ModelConfiguration` in `Utilities/AppLaunchBootstrapper.swift` before you apply any of it.
- **Do not run `ios-memory-perf`.** It is measure-first and symptom-triggered, and it is deliberately
  outside the routing table.

## Things file 1 turned up that touch file 2

These are context, not instructions. Judge them yourself.

1. **`colorForCategory` is duplicated in four views** — `TaskAddView`, `TaskEditView`,
   `TaskTemplateSelectionView`, and `BulkTaskEditView` each hold the same switch over
   `CareTaskCategory`. `CareTaskCategory` is declared in `CareTask.swift:133`. A `color` property on
   the enum would delete all four copies. File 1 left the duplication alone on purpose, to keep its
   diff inside file 1. This is a natural file-2 finding.
2. **`Set<Cat>` of `@Model` objects** — `TaskAddView` and `TaskEditView` both hold cat selections in
   a `Set<Cat>`, which relies on `PersistentModel` identity hashing. Whether that is safe across a
   context save is a SwiftData question, so it belongs to this pass.
3. **`task.schedules.filter { $0.isActive }`** is read from view code in several places. Check
   whether the relationship and its delete rules make that traversal cheap.

## What file 1's fixes changed, in case you touch the same code

`TaskAddView.swift` dropped from 1328 to about 590 lines. New files, all under `Views/Tasks/`:

- Section views: `TaskAddTitleSection`, `TaskAddNotesSection`, `TaskAddDateSection`,
  `TaskAddTimeSection`, `TaskAddCategorySection`, `TaskAddPrioritySection`,
  `TaskAddCaregiverSection`, `TaskAddFrequencySection`, `TaskAddCustomFieldsSection`,
  `TaskAddFeedingDetailsRow`.
- Feeding types moved out of `TaskAddView.swift`: `FeedingPortionUnit`, `FeedingDetailsSheet`,
  `FeedingMenuRow`, `FeedingFieldStatusRow`, plus new `FeedingTextField`,
  `FeedingFoodOptionsList`, `FeedingDetailsField`.
- `FeedingFieldSupport` — the portion encode, decode, and display rules, pulled out of the view so
  they can be tested. **No tests cover it yet.** That is an open gap.

`TaskEditView.swift` (file 5) holds near-identical feeding code that was **not** touched. When file 5
comes up, `FeedingFieldSupport` is the seam to reuse.

## Verification commands

The project uses file-system synchronized groups, so a new `.swift` file under `CatCareCalendar/`
joins the target with no `project.pbxproj` edit.

Prefer `xcodebuildmcp`. Call `session_show_defaults` first. One simulator at a time — this machine
has 16GB.

```bash
# Unit tests only (283 tests, all green as of file 1's fix commit)
# via xcodebuildmcp: test_sim({ extraArgs: ["-only-testing:CatCareCalendarTests"] })
```

`tap` was **not** available in the file-1 session, so on-simulator interaction could not be driven.
`snapshot_ui` and `screenshot` did work. If you need taps, check the tool list before you plan a UI
verification, and fall back to `CatCareCalendarUITests`.

## Known limits of the skill setup

Unchanged from `docs/swift-skill-recheck-handoff.md`. In short: the hook only reminds, it does not
enforce; only `Edit`/`MultiEdit`/`Write` fire it; dedupe is per session and substring-based; and the
subagent behavior is still unverified.

The hook was confirmed live on 2026-08-14 in `.claude/settings.local.json`, with matcher
`Edit|MultiEdit|Write`.
