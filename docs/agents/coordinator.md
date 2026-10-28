# Coordinator: Purrtine project facts

The process is the user-level `/issue-batch-coordinator` skill (`~/.claude/skills/issue-batch-coordinator/`). This file holds only the Purrtine facts that skill's "Project facts" section asks for.

| Fact | Purrtine |
|---|---|
| GitHub repo slug | `bckizildemir/Purrtine` (`gh` at `/opt/homebrew/bin/gh`) |
| Session name prefix | `purrtine-` (sessions `purrtine-<N>`, worktrees `issue-<N>`) |
| Prompt template | `docs/agents/implement-session-prompt.md` |
| Review brief | `docs/agents/pr-review-brief.md` |

## Standing rules

- A batch needs no `decision-check` run. (Set 2026-10-11.)
