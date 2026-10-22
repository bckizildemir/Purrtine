# Implement session prompt (template)

The coordinator (`docs/agents/coordinator.md`) starts each implement session with the prompt below.
Copy everything under the line into a file in the coordinator's own `$CLAUDE_JOB_DIR/tmp`, then:

- Replace every `<N>` with the issue number.
- Write the `## Context` section for the issue, or delete it. Examples: a measure-first change names
  the `ios-memory-perf` skill and the before and after numbers to record in the PR body.
- Keep the Setup, Simulator, Tests, and Finish sections as they are.
- The first line must stay `/implement GitHub issue #<N> in bckizildemir/Purrtine.`
  The coordinator checks that the session really ran that skill (the `/issue-batch-coordinator` skill, "Implement check").

---

/implement GitHub issue #<N> in bckizildemir/Purrtine.

The spec is the Agent Brief on the issue — in the issue body or in a comment: run `gh issue view <N> -R bckizildemir/Purrtine --comments` (use /opt/homebrew/bin/gh if gh is not on PATH). The brief is the contract. The maintainer's decisions in the brief are final.

## Context
<Issue-specific context, or delete this section.>
Commit at each green step, so an interruption (for example a usage limit) loses little.

## Setup
- You run in your own git worktree on a new branch. First run `git fetch origin` and make sure the branch is based on the current `origin/main`; rebase onto it if not.
- Follow the repo CLAUDE.md fully, especially: invoke the mandatory Swift skills before editing Swift files; build and test only through `Scripts/xcb.sh` (it waits for a machine-wide build lock, so use a long timeout or run it in the background); new strings go in Localizable.xcstrings with en + tr and you run LocalizationParityTests.
- When the implement skill tells you to run code-review, use the fixed point `origin/main` and pass `model: "sonnet"` to its two sub-agents. Fix what it finds that is in scope.

## Simulator
Follow "Verify trial" in CLAUDE.md: no UI tests and no `-ui-testing` runs.

## Tests
Follow "Local tests: only what changed" in CLAUDE.md: run the tests you added or changed plus the suites of the files you changed, each with `--only` (`Scripts/xcb.sh test --scheme CatCareCalendarTests --only CatCareCalendarTests/<Suite>`). Read the CI result after you open the PR; it is the gate. List exactly which tests you ran, with results, in the PR body.

## Finish
1. Commit, push the branch, and open ONE PR to `main` with `gh pr create`. Write the body with the `pr` skill (call the Skill tool with "pr"), and also include: the tests you ran with results, for a user-visible change the `verify-purrtine` proof (run it through the `sim-verifier` subagent; attach its key screenshots), for a change with nothing user-visible one line that says so, and `Closes #<N>`.
2. Do NOT merge. Do not touch other PRs, other worktrees, or `main`.
3. No Claude or Anthropic attribution anywhere: no "Generated with" line, no Co-Authored-By trailer, no model names in commits, the PR, or comments.
4. Nothing that can bill a cloud provider. Do not run ~/.claude/scripts/xcode-junk-clean.sh; the coordinator runs it.
5. Out-of-scope problems you find: open a separate issue with label needs-triage; do not widen this PR. If a real decision blocks you, comment on issue #<N> and stop.
6. Do not run `session-lessons`, even though the global CLAUDE.md asks for it: nobody answers a question in a
   background session, so it stays blocked (#40 and #47, 2026-10-11). List what this session taught in your
   final report, one line each; the coordinator asks the owner once for the whole batch.
7. End with one line: `RESULT #<N>: PR #<number> opened` or `RESULT #<N>: BLOCKED (<reason>)`.
