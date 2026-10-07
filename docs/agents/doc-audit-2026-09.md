# Documentation audit — 2026-09-08

**Scope:** the agent-facing documentation of this repo — `CLAUDE.md`, `.claude/rules/*.md`,
`.cursor/rules/*.mdc`, `docs/**`. **Branch:** `docs/reconcile-agent-docs`, cut from `main` @ `5b8b332`.
**Method:** claim by claim. Each factual assertion was located as `path:line`, checked with a command
against the code on this branch, given a verdict, then fixed, corrected in place, or rewritten as a
pointer.

**Why this exists.** `CLAUDE.md` loads into every agent session and is treated as binding, so a wrong
line in it produces wrong work. One example from this session's evidence: `CLAUDE.md` said the project
"has no third-party dependencies", an agent believed it, and planned a Swift 6 concurrency migration
on that basis. A project-wide `SWIFT_STRICT_CONCURRENCY = complete` in fact crashes the compiler on
the vendor SDK's `FirebaseAuth` target. One false line nearly sent a migration into a wall.

**Standard applied:** a claim is verified against the code, or it is removed. An unverifiable claim is
worse than no claim.

## Result

| | Count |
| --- | --- |
| Claims checked | 118 |
| **false** (never true, or wrong as written) | 14 |
| **stale** (true when written, not true now) | 17 |
| **unverifiable** (cannot be checked from this repo) | 6 |
| **true** (left alone) | 81 |

Files changed: `CLAUDE.md`, `.claude/rules/swift-skills.md`, `docs/agents/domain.md`,
`docs/agents/triage-labels.md`, `docs/architecture-review.md`,
`docs/architecture-review-handoff.md`, `docs/swift-skill-recheck-handoff.md`,
`docs/swift-skill-recheck-file2-handoff.md`, `docs/swift-skill-recheck-file3-handoff.md`,
`docs/swift-skill-recheck-file4-handoff.md`, `docs/swift-skill-recheck-summary.md`,
`docs/swift-skill-trigger-setup.md`, `.cursor/rules/general-swiftui.mdc`,
`.cursor/rules/design-patterns.mdc`, `.cursor/rules/navigation.mdc`, `.cursor/rules/testing.mdc`.

No `.swift` file was touched. No production code changed.

## The three most dangerous findings

1. **"No third-party dependencies"** — `CLAUDE.md:31`, `docs/architecture-review.md:3`. False. The app
   links `firebase-ios-sdk` (four products, two importing files). This is the claim that nearly broke
   the concurrency migration. `CLAUDE.md` now carries a `### Dependencies` section that states the
   package, the products, the importing files, and the strict-concurrency crash.
2. **"`@concurrent` is unavailable at `SWIFT_VERSION = 5.0`"** — five places across the
   `swift-skill-recheck-*` documents. False. `SWIFT_VERSION` selects the language mode; the host
   toolchain is Swift 6.4 and the syntax compiles today at iOS 18.4. The framing conflated three
   separate limits (language mode, toolchain, API availability), and only the third one blocks an API.
   Every instance is corrected in place, and `CLAUDE.md`'s reconciliation notes now state the three
   limits separately.
3. **"All local notification scheduling goes through `NotificationManager`"** — `CLAUDE.md:83`,
   `.claude/rules/swift-skills.md:51`. False as an absolute. `Views/Settings/SettingsDebugViews.swift`
   builds a `UNNotificationRequest` and calls `UNUserNotificationCenter.current().add(_:)` directly,
   and three views reach `NotificationManager.shared` rather than the injected protocol. The rule is
   now stated as the standard. **Since closed** — the owner had the debug path routed through
   `NotificationManager`, so the rule is absolute again; see decision 5.

## Claim ledger

Verdicts: **T** true · **F** false · **S** stale · **U** unverifiable.

### `CLAUDE.md`

| Claim | Where | Verdict | Command | Action |
| --- | --- | --- | --- | --- |
| "has no third-party dependencies" | :31 | **F** | `grep -o 'repositoryURL = [^;]*' …/project.pbxproj` → `firebase-ios-sdk` | Replaced with a `### Dependencies` section |
| `Package.resolved` exists at the workspace path | :— | **F** | `git ls-files`, `find . -name Package.resolved` | Was untracked and absent from this worktree. Now tracked — see decision 2 |
| "57 files import SwiftData" | :25 | **S** | `grep -rl 'import SwiftData' … CatCareCalendar \| wc -l` → 42 | Corrected to 42, with the recount command |
| `SWIFT_VERSION = 5.0`, target 18.4 | :31, :135 | **T** | `grep -o 'SWIFT_VERSION = [^;]*' …` | Kept; framing corrected |
| Swift 6.2 syntax unusable here (implied) | :135 | **F** | Swift 6.4 toolchain; see the sibling assessment | Reconciliation note rewritten as three separate limits |
| iPhone 12 / iOS 18.5 and 26.5 destinations resolve | :62 | **T** | `xcrun simctl list devices available` | Kept; noted that an iOS 27.0 runtime is also installed and is not the baseline |
| Xcode / Swift host versions | — | new | `xcodebuild -version`, `swift --version` → Xcode 27.0, Swift 6.4 | Added |
| `-only-testing:CatCareCalendarTests/TaskActionServiceTests` resolves | :47 | **T** | `ls CatCareCalendarTests/Utilities/` | Kept |
| `buildServer.json` present | :65 | **T** | `test -e buildServer.json` | Kept |
| Launch order: container → caregiver → seed → coordinator | :70 | **T** | `CatCareCalendarApp.swift:14-42` | Kept |
| `@Entry` environment values for router and haptics | :71 | **T** | `grep -rn '@Entry'` | Kept |
| Router flags `shouldNavigateToMyCats`, `shouldTriggerAddTask` | :72 | **T** | `NavigationRouter.swift:14-16` | Kept; `shouldNavigateToHistory` added and `AppTab`'s four cases named |
| Models are `Cat`, `CareTask`, `CareTaskTemplate`, `RepeatConfiguration` | :75 | **F** | `grep -rn -A2 '^@Model'` | The five `@Model` types are `Cat`, `CareTask`, `CareTaskSchedule`, `CareTaskCompletion`, `Caregiver`. `CareTaskTemplate` and `RepeatConfiguration` are plain structs. Corrected |
| Presentation structs all exist | :75 | **T** | `find . -name '<Type>.swift'` for all 30 named types | Kept |
| Cloud tier absent from the architecture section | :69-77 | **F** | `FirebaseBootstrapper.swift`, `TaskAssistantCloudInterpreter.swift` | New `### Cloud tier` subsection added |
| `Utilities/` inventory | :77 | **S** | `ls CatCareCalendar/Utilities` | Ten services were missing (resync, `TaskActionService`, photos, backports). List extended and marked non-exhaustive |
| "prefer a changelog entry over expanding `CHANGELOG.md`" | :80 | **F** | `test -e CHANGELOG.md` → absent | Rewritten: there is no root `CHANGELOG.md` |
| All scheduling centralized in `NotificationManager` | :83 | **F** | `grep -rln 'UNNotificationRequest' … CatCareCalendar` | Restated as the standard; the debug exception and the three view call sites are named |
| `@Query` only inside views | :87 | **T** | `grep -rln '@Query' … \| grep -v '/Views/'` → empty | Kept |
| Explicit delete rules on relationships | :88 | **T** | `grep -rn 'deleteRule'` → 4 | Kept; explicit `inverse:` keys and the versioned schema added |
| Versioned schema absent from the doc | :86-88 | **S** | `CatCareSchemaV1.swift`, `CatCareMigrationPlan.swift` | Added, with the "never edit V1" rule |
| "Enforced via `.cursor/rules/*.mdc`" | :92 | **F** | Claude Code does not load `.cursor/rules/`; in Cursor, `accessibility.mdc` and `testing.mdc` are `alwaysApply: false` with no `globs:`, so nothing attaches them | Rewritten: written down, not enforced |
| `@Observable` classes are "`@MainActor` by default" | :98 | **F** | `SWIFT_DEFAULT_ACTOR_ISOLATION` unset, so the compiler grants nothing. Audited before the Swift 6 concurrency merge, when `NavigationRouter` was the counter-example; that merge made all five `@Observable` classes `@MainActor`, so the convention now holds by hand everywhere | Restated as a convention, with the counter-example |
| No `AnyView`; one `GeometryReader` | :101 | **T** | `grep -rl 'AnyView'` → 0 | Kept |
| Localization mechanism, symbols, `localizedDataKey`, `defaultCaregiverLocalizationKey`, `home.routine_status.days_ago`, `LocalizationParityTests` | :106-110 | **T** | greps for each symbol and key | Kept unchanged — this section was accurate throughout |
| No `String(format:)` / `NSLocalizedString` for known strings | :108 | **T** | 2 hits, both the sanctioned data-key path | Kept |
| `TestSupport` provides three doubles | :123 | **S** | `ls CatCareCalendarTests/TestSupport` | `FakeTaskAssistantCloudInterpreter` and `SchemaBaselineHarness` added |
| Zero `DateFormatter`/`DispatchQueue` in the app target | :137 | **T** | `grep -rln 'DateFormatter\|DispatchQueue' … CatCareCalendar` → empty | Kept |
| `.claude/skills/swift-style-guide/SKILL.md` exists | :139 | **T** | `test -e` | Kept |
| Bundle id `com.berkecankizildemir.CatCareCalendar` | :152 | **T** | `grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*'` | Kept |
| A worktree inherits the `PostToolUse` hook | :182 | **S** | Herdr worktrees live under `~/.herdr/worktrees/`, outside the repo | Qualified: true for `.claude/worktrees/`, false for a Herdr pane |
| The hook names six of the eight rows | :195 | **T** | Read `.claude/settings.local.json` in the main checkout: six skill names present, `ios-memory-perf` and `swift-style-guide` absent | Kept |
| Five triage roles are used verbatim as label strings | :210 | **F** | `gh label list` | Two of the five labels do not exist. Pointer added |
| Bulk task edit described nowhere | — | gap | `BulkTaskEditView` has no reference outside its own file | An explicit "not a feature" bullet added, pointing at ADR 0001 |

### `.claude/rules/swift-skills.md`

| Claim | Where | Verdict | Action |
| --- | --- | --- | --- |
| "57 files import it" | :36 | **S** | Corrected to 42 app-target files |
| `@Model` types list | :37 | **F** | Corrected to the five real ones; the two structs called out |
| Nine files use Liquid Glass | :43 | **T** | Kept — still exactly 9 |
| One UITest file uses XCTest | :46 | **T** | Kept |
| `TestSupport` inventory | :47-49 | **S** | Two doubles added |
| `@Observable` types are `@MainActor` when they mutate observed state | :50 | **T** | Kept, with the "convention, not default" qualifier |
| Views and services never schedule directly | :51-52 | **F** | Debug exception named |
| Vendor dependency, strict-concurrency crash | — | gap | Added as a repo fact |
| Language mode vs toolchain | — | gap | Added |

### `.cursor/rules/*.mdc` — since deleted

These nine files were corrected on 2026-09-08 and deleted on 2026-09-09 (decision 6). The rows stay
as the record of what the copy got wrong, which is the case for not keeping a second copy.

| Claim | Where | Verdict | Action |
| --- | --- | --- | --- |
| "the current project file shows only the app target" | `testing.mdc:13` | **F** | Both test targets exist and are wired in. Corrected |
| "Run iOS verification on `iPhone 16` with `iOS 18.5`" | `testing.mdc:54` | **F** | Contradicted `CLAUDE.md`'s baseline. Corrected to the iPhone 12 pair |
| "the app is a 3-tab experience" | `navigation.mdc:11` | **F** | `AppTab` has four cases. Corrected |
| Version-gap framing | `general-swiftui.mdc:13` | **F** | Rewritten: language mode, toolchain, availability |
| "Do not introduce third-party dependencies" | `general-swiftui.mdc:21` | **T** as policy, misleading as fact | Kept as policy; the existing dependency named |
| "Keep those models `@MainActor` by default" | `design-patterns.mdc:16` | **F** as a statement of behaviour | Restated as a convention |
| Localization glob and symbol claims | `localization.mdc:5-43` | **T** | Kept — `CatCareCalendar/Resources/**/*.xcstrings` matches the real catalog path, and every symbol and key named exists. This is the only one of the nine files that scopes itself by path |
| `@Query` only in views | `design-patterns.mdc:22`, `performance.mdc:37` | **T** | Kept |
| No `NavigationView` | `navigation.mdc:54` | **T** | Kept — zero occurrences |
| No `[weak self]` in view `.task` | `performance.mdc:24` | **T** | Kept |
| 44×44pt touch targets, accessibility priorities | `accessibility.mdc:29,42` | **U** as measurements | Left as rules, which is what they are |
| `AppDestination`, `TaskListModel` and similar names in code samples | `navigation.mdc:21-24`, `state-management.mdc:23-46` | **U** | Left alone — illustrative samples, not claims about this repo |

### `docs/architecture-review.md` and its handoff

Dated snapshot of `main` @ `5c6527e`, 31 July 2026. Kept as a record; not rewritten.

| Claim | Verdict | Action |
| --- | --- | --- |
| "no third-party dependencies" (`:3`) | **F** | Corrected in the header |
| Issues #12–#15 are agent-ready | **S** | All four are now closed; #16–#21 remain open. Banner added to both files |
| Line counts (`TaskAddView` 1477, `TaskEditView` 781, …) | **S** | `TaskAddView.swift` is 663 lines now. Banner records the drift and says re-measure |
| `path:line` citations throughout | **S** | Banner states they are no longer reliable |
| "`BulkTaskEditView` has no production entry point" (`:138`) | **T** | Re-verified: no reference outside its own file. Kept, and tied to ADR 0001 |
| Seven candidates, four defects, issue mapping | **T** | Kept |
| `.scratch/architecture-review/` exists locally | **U** | Gitignored and machine-local. Left alone |
| Skill enablement table | **U** | Depends on the workspace, not the repo. Left alone |

### `docs/swift-skill-recheck-*.md`

Five dated session records from 2026-08-14.

| Claim | Where | Verdict | Action |
| --- | --- | --- | --- |
| "`@concurrent` … unavailable at `SWIFT_VERSION = 5.0`" | `file3:85`, `file4:49`, `summary:156` | **F** | Corrected in place at each site |
| "A finding that assumes Swift 6.2 is not actionable here" | `handoff:54`, `file2:46`, `file3:44` | **F** | Split into syntax versus availability |
| "file 2/3/4/5 is **Your job** / Not started" | `file2:23`, `file3:22`, `file4:23` | **S** | A CLOSED banner added to each of the three; file 1 already had one |
| "`docs/swift-skill-recheck-handoff.md` is not on this branch" | `file2:10`, `file3:10`, `file4:11` | **S** | All five documents are on `main`. Struck through and resolved |
| "One document is still missing from this branch" | `summary:24` | **S** | Struck through and resolved |
| "`TaskEditView` is now the only remaining direct `NotificationManager.shared` caller in view code" | `file4:155` | **F** | Three views call it. Corrected with line numbers |
| CloudKit does not apply | `file3:47` | **T** | Re-verified: no `cloudKitDatabase`, no entitlements file, no source reference. Kept |
| "No test file references `checkCancellation` or filters `CancellationError`" | `summary:146` | **T** | Still true. Kept as an open gap |
| `CareTask.swift` has no custom-field storage | `summary:135` | **T** | Still true. Kept as the open gap that matters most |
| `colorForCategory` duplicated in four views | `summary:122` | **T** | Still four copies. Kept |
| `Date.taskDayLabel` in `Utilities/TaskDateLabel.swift` | `summary:222` | **T** | Kept |
| "296 tests in 41 suites passed" | `summary:248` | **S** | A measured figure from a real run; a grep now counts 306 `@Test` attributes. Not overwritten with a grep — a test count needs a test run |
| Explicit inverses on `schedules` and `completions` | `summary:47` | **T** | Four `inverse:` keys present. Kept |

### `docs/swift-skill-trigger-setup.md`

| Claim | Where | Verdict | Action |
| --- | --- | --- | --- |
| 57 SwiftData / 38 Swift Testing / 144 app files | :206 | **S** | Re-measured: 42 / 40 / 167. Corrected |
| `navigationTitle` in 20 files, `.toolbar` in 16–18 | :117, :207 | **S** | Re-measured: 21 and 17. Corrected |
| 9 Liquid Glass, 1 XCTest, `ToolbarSpacer` in 2 | :206-207 | **T** | Unchanged in six weeks. Kept |
| `CLAUDE.md` is 214 lines / 18.9 KB | :70 | **S** | This audit took it to 260 lines / 27.7 KB. Corrected, with the headroom noted |
| Six of eight rows hook-backed | :194 | **T** | Verified against the installed hook. Kept |
| `permissions.allow` holds 5 entries | :123, :181 | **T** | Verified. Kept |
| A `.claude/worktrees/` worktree inherits the hook | :119 | **T** | Kept; the Herdr case added as the exception |
| Deployment-target reconciliation framing | :208 | **F** | Rewritten as three separate limits |
| "pushed but not yet merged" | :286 | **S** | On `main` now. Corrected |
| `~/.claude/skills` holds 19 skills | :207 | **T** | `ls ~/.claude/skills \| wc -l` → 19. Kept |
| "live fire still unverified" | :3 | **U** | Needs the user to open `/hooks`. Left standing — it is honest about its own limit |
| TTB claims (paths, counts, Firestore, 18.2 target) | :225-258 | **U** | Another repository, not readable from here. Left alone, and they stay labelled as TTB's |

### `docs/agents/*.md`

| Claim | Where | Verdict | Action |
| --- | --- | --- | --- |
| "`docs/adr/` does not exist yet" | `domain.md:12` | **S** | Time-dependent assertion removed; the advice now says to check the directory |
| Tracker is `bckizildemir/CatCareCalendar` via `gh` | `issue-tracker.md:3` | **T** | `git remote -v`. Kept |
| `gh` command forms, sub-issue and dependency endpoints | `issue-tracker.md:7-45` | **T** where checkable | Kept; not exercised with writes |
| "PRs as a request surface: no" | `issue-tracker.md:18` | **T** | A settings flag, not a code claim. Kept |
| Five triage labels exist in the tracker | `triage-labels.md:7-11` | **F** | `needs-triage` and `needs-info` do not exist. An **Exists?** column added, with the create command and an instruction to ask first |
| `documentation/PRD.md`, `features/`, `changelogs/` | `domain.md:33-35` | **T** | All present. Kept |

## Decisions — all six settled 2026-09-09

The audit raised six questions that documentation could not answer. The owner has decided all six.
Each outcome is below. Treat these as closed, not as open questions to re-raise.

1. **Orphaned bulk-edit code — DECIDED: delete.** Branch `chore/remove-bulk-edit-and-debug-notify`
   removes `BulkTaskEditView`, `BulkTaskEditService`, their test suite, and 22 orphaned
   `tasks.bulk.*` / `cats.bulk_actions` String Catalog keys. Product record:
   `docs/adr/0001-no-bulk-task-edit.md`.
2. **`Package.resolved` — DECIDED: track it.** Done on this branch, to pin the vendor SDK version
   (the project pins only `upToNextMajorVersion` from 11.7.0, and that version decides whether a
   strict-concurrency build crashes). The gotcha, since `.gitignore` cannot confess it: `*.xcworkspace`
   at `.gitignore:4` ignores the whole `project.xcworkspace` **directory**, git never descends into an
   ignored directory, so a plain `git add` did nothing and a lone `!…/Package.resolved` could not
   re-include it. Each parent directory on the path needs its own negating rule. Verify with
   `git check-ignore -v CatCareCalendar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
   — it prints nothing today.
3. **The two missing triage labels — DECIDED: create them.** `needs-triage` and `needs-info` now exist
   in the tracker, so all five canonical roles have a label. `docs/agents/triage-labels.md` is updated.
4. **Four `@Model` types in `CareTask.swift` — DECIDED: leave it, for now.** A split would collide with
   issue #16's refactor of the same file. Revisit after #16 merges; the decision is a comment on #16.
5. **The debug notification path — DECIDED: fix it.** Branch
   `chore/remove-bulk-edit-and-debug-notify` routes the debug UI through `NotificationManager`, so the
   "all scheduling goes through `NotificationManager`" rule is absolute again.
6. **`.cursor/rules/` — DECIDED: delete.** Done on this branch; `CLAUDE.md` is the single source of
   conventions, and `GEMINI.md` and `AGENTS.md` point at it. `.cursor/commands/` and
   `.cursor/worktrees.json` stay — they are not rule duplicates.

## For the next audit

- Every count in this repo's documentation now carries the date it was measured on. Trust the date,
  not the number: between 2026-07-31 and 2026-09-08, five of seven counts drifted.
- The pattern that produces the worst failures is not an out-of-date number. It is an **absolute
  claim** — "all X goes through Y", "no third-party dependencies", "API Z is unavailable". Each one
  reads as permission to skip a check. Verify the absolutes first.
- Dated session records (`architecture-review*`, `swift-skill-recheck-*`) are worth keeping and not
  worth rewriting. Give them a banner that says what changed, and correct the specific lines an agent
  might act on.
