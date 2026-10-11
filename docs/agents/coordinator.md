# Coordinator: Purrtine project facts

The process is the user-level `/issue-batch-coordinator` skill (`~/.claude/skills/issue-batch-coordinator/`). This file holds only the Purrtine facts that skill's "Project facts" section asks for.

| Fact | Purrtine |
|---|---|
| GitHub repo slug | `bckizildemir/Purrtine` (`gh` at `/opt/homebrew/bin/gh`) |
| Session name prefix | `purrtine-` (sessions `purrtine-<N>`, worktrees `issue-<N>`) |
| Prompt template | `docs/agents/implement-session-prompt.md` |
| Review brief | `docs/agents/pr-review-brief.md` |
| Simulator lock | `/tmp/purrtine-sim.lock` (take and release as the prompt template says) |
| Test simulators | `iPhone 12` on iOS 26.5 (manual checks, default) and `iPhone 12 (iOS 18.5)` on iOS 18.5; run passes one after the other, never boot both |

## Standing rules

- TriQ shares the `iPhone 12` (iOS 26.5) simulator and may ignore `/tmp/purrtine-sim.lock`. The prompt template tells sessions how to detect a TriQ run and repeat a measurement.
- A batch needs no `decision-check` run.
- Known time-of-day failure (#41, open as of 2026-10-11): `CriticalFlowsUITests.testCalendarOneTapCompletionWithStaleRemindersWarns` fails when it runs after 21:00 local time, because its seeded task falls on tomorrow. A failure of that test after 21:00 is #41, not a regression of the PR under review.
