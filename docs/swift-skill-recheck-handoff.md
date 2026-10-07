# Handoff — recheck the five hot files with the Swift review skills

**Written:** 2026-08-14 · **Scope:** one review pass over five files · **Run this at medium effort.**

> ## Status: CLOSED. Do not run this pass again.
>
> The pass ran on 2026-08-14 and finished. All five files were reviewed and fixed on branch
> `worktree-fix-taskaddview-review`, in twelve commits. The outcome is in
> `docs/swift-skill-recheck-summary.md` **on that branch**, with per-file evidence in
> `docs/swift-skill-recheck-file2-handoff.md`, `-file3-`, and `-file4-`.
>
> That branch was pushed but nobody opened a pull request for it, so the work sat unmerged and
> invisible for two days. That is how this document came to still read as pending. Everything below
> this banner is the original brief, kept as the record of what was asked for.
>
> **What is actually left:** review and merge that branch. Nothing in this document is outstanding
> work.

## Why this doc exists

The Swift review skills were not firing on Swift edits in this repo. That was proven from the transcripts: across the 8 most recent sessions, three of them made 16, 7, and 5 `Edit`/`Write` calls on `.swift` files with **zero** `Skill` calls.

Two fixes landed on 2026-08-14:

1. A **Swift review skills** route table in `CLAUDE.md`, under `## Agent skills` (line 105).
2. A **`PostToolUse` hook** in `.claude/settings.local.json` that names the matching skill after any `Edit`/`MultiEdit`/`Write` on a `.swift` path.

The five files below were written *before* those fixes, and they are the highest-churn files in the app. They have never been through the skills. This pass closes that gap — and it doubles as the end-to-end proof that the new setup works.

## Before you start

**Confirm the hook is live.** Open `/hooks` and look for the `PostToolUse` entry with matcher `Edit|MultiEdit|Write`. If it is missing, restart the session — hook registration may not apply mid-session. A dead hook does not block this pass, but it makes the pass worth less as proof.

**Run at medium effort.** This is a read-and-report pass. It does not need high effort, and limits drain fast.

## The work

One file at a time. Finish a file's report before the next file starts. **No full-repo sweep.**

| # | File (under `CatCareCalendar/`) | Lines | Skills to run |
| --- | --- | --- | --- |
| 1 | `Views/Tasks/TaskAddView.swift` | 1328 | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` |
| 2 | `Models/CareTask.swift` | 749 | `swiftdata-pro` |
| 3 | `Models/TaskAssistantViewModel.swift` | 724 | `swiftdata-pro`, `swift-concurrency-pro` |
| 4 | `Utilities/NotificationManager.swift` | 718 | `swift-concurrency-pro` |
| 5 | `Views/Tasks/TaskEditView.swift` | 710 | `swiftui-pro`, `swift-concurrency-pro`, `ios-navigation-chrome` |

That routing was verified against these exact files on 2026-08-14 — it is what the hook injects. Trust it; don't re-derive it.

## Rules for the pass

- **Report only. Fix nothing in this pass.** Every fix is its own change, and gets its own review.
- **Group findings by file, then by severity.** Real problems only — all four skill bodies say "Report only genuine problems - do not nitpick or invent issues." Honour that.
- **Reconcile against this repo's reality before you report.** `IPHONEOS_DEPLOYMENT_TARGET = 18.4` and `SWIFT_VERSION = 5.0`. A finding that assumes an iOS 26 API is not actionable here — flag the gap, don't report the iOS 26 API as the fix. **Correction, 2026-09-08:** read `SWIFT_VERSION` as the language mode only. Swift 6.2 *syntax* compiles here on the Swift 6.4 toolchain; the 18.4 deployment target is what limits iOS 26 *APIs*. See the reconciliation notes in `CLAUDE.md`.
- **Negative control, if the hook is live:** an edit to `CLAUDE.md` or `CatCareCalendar/Style/Theme.swift` must inject nothing. Silence there is correct.

## What not to do

- Don't re-measure the skip evidence. It is recorded above.
- Don't re-derive the routing table. It is tested.
- Don't run `ios-memory-perf` on every edit. It is measure-first and symptom-triggered, and the hook deliberately leaves it out. It is still a row in the `CLAUDE.md` routing table. Run it on a reported symptom, a deliberate perf pass, or a review of image loading, body-read computed properties, or `@Query` cost.
- Don't edit the skills under `~/.claude/skills/` or `~/.agents/skills/`. They are third-party (MIT, Paul Hudson), and the user has ruled that out. Skills stay as skills.

## Where this leads

These five files were chosen because the architecture review builds on them:

- **CatCareCalendar#16** (care-task mutation seam) — top recommendation. Touches files 1, 2, 3, 5.
- **[#1](https://github.com/bckizildemir/Purrtine/issues/1)** (recurrence rule, old CatCareCalendar#17) — second. Touches file 2.

Both are *deepenings*, and per `docs/architecture-review-handoff.md` they need a design conversation before any Swift is written. This review pass is useful input to that conversation, not a substitute for it. **CatCareCalendar#28** and **CatCareCalendar#33** are build-ready now if you want code work instead.

## Known limits of the new setup

- **A note is not compliance.** The hook only reminds. Running the skill is still a model action, by the user's choice.
- **Bypass routes.** Only `Edit`/`MultiEdit`/`Write` fire the hook. Edits through `Bash`, through `xcodebuildmcp`, or in Xcode do not. The `CLAUDE.md` table covers those.
- **Dedupe is per session and substring-based.** A skill run early suppresses later reminders for that skill, even after auto-compact may have evicted its body. Accepted: a missed reminder is cheaper than a nagging one.
- **Subagents are unverified.** Whether `Task`-spawned agents fire this hook, and against which transcript, is untested. Worth a check early — Swift work often runs in subagents.

## State at handoff time

Updated 2026-08-16. The setup this pass depends on is now committed, on branch
`docs/swift-skill-triggers`, cut from `origin/main`:

- `CLAUDE.md` — the `## Swift skills are mandatory` section and its routing table.
- `.claude/rules/swift-skills.md` — the same routing, fired when an agent reads a Swift file.
- `docs/swift-skill-trigger-setup.md` and this file.

Two corrections that landed with it, both worth knowing before you trust an older copy of these
docs:

- **The first draft of this work was written on a stale branch.** It sat on
  `fix/remove-orphan-cats-selection-done`, which was behind `origin/main` by ten commits, and main
  had since trimmed `CLAUDE.md` by 76 lines by moving the Paul Hudson guide into the
  `swift-style-guide` project skill. Committing that draft as-is would have resurrected the removed
  block. The work was rebuilt on `origin/main` instead.
- **`CLAUDE.md` on main carried `## Agent skills` twice**, the earlier copy missing the triage-label
  entry. The duplicate is removed.

`.claude/settings.local.json` holds the hook and is covered by `~/.gitignore_global:4`, so it never
stages. A fresh clone therefore gets the table and the rules file but not the hook — section 4 of
`docs/swift-skill-trigger-setup.md` installs it.
