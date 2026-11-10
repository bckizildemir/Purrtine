# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Last updated

2026-11-11

Last session:
- PR #99 (CI prints UI-test retry results) was not merged: its checks are green, but it now conflicts with
  `main` in `.github/workflows/ci.yml` since the rename in #112.
- Opened PR #118 (Tasks rows show the category icon, fixes #116) and PR #119 (Whiskers skips tasks done
  today in the "which task?" card, fixes #117). Both had a swift-reviewer pass; review fixes are in.
- Removed 25 worktrees whose PRs were merged and that had no local work; kept 6 (see the session report).
- `session-lessons` skill now ends with "update STATUS.md". Lessons added: worktree names `wt-p<N>` /
  `wt-t<N>` (global CLAUDE.md), squash-merge check (coordinator.md), real completion path in tests (testing.md).

## Open PRs

| PR | What it does | Waits for |
|---|---|---|
| #99 | CI: print UI-test retry results in the ui-tests job (#97) | Rebase on `main` to fix the `ci.yml` conflict, green CI, then merge; then close #97 |
| #118 | Tasks list: category icon on each task row (#116) | Owner review, a light/dark look on the simulator, merge |
| #119 | Whiskers: skip tasks already done today in the "which task?" card (#117) | Owner review, merge |
| #120 | This file and the CLAUDE.md pointer | Owner review, merge |

## Next step

1. Fix the #99 conflict in a separate session (not the one that merges it), wait for CI, merge, close #97.
2. Owner reviews and merges #118, #119 and #120.
3. Then pick the next issue: #9 (feeding details saved, schema V2) is `ready-for-agent`.

## Waits for the owner

- #12 (App Store readiness): the Groq retention window and the App Store ID.
- #118: is a category icon next to the completion circle clear, or does it read as a second button?
- #119: a daily task that was overdue and is caught up today gets its next due date today. Whiskers now
  counts it as done ("already done today", same rule as Home's "Last done: Today"), so that second
  same-day occurrence can only be completed from the Tasks list. Confirm this choice before merging.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
