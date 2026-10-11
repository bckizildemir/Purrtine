# Implement session prompt (template)

The coordinator (`docs/agents/coordinator.md`) starts each implement session with the prompt below.
Copy everything under the line into a file in the coordinator's own `$CLAUDE_JOB_DIR/tmp`, then:

- Replace every `<N>` with the issue number.
- Write the `## Context` section for the issue, or delete it. Examples: a measure-first change names
  the `ios-memory-perf` skill and the before and after numbers to record in the PR body; a change
  that hands off between alerts, sheets, or a disappearing view names the `-keep-animations` check
  from `.claude/rules/testing.md`; a UI test change names the simulators it must pass on.
- Keep the Setup, Simulator lock, Tests, and Finish sections as they are.
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

## Simulator lock (other sessions share this Mac and its simulators)
Before ANY use of a simulator — every `Scripts/xcb.sh test` run, and any xcodebuildmcp or simctl install/launch/screenshot/UI check/measurement — take the simulator lock, and release it as soon as you finish:
- take: `until mkdir /tmp/purrtine-sim.lock 2>/dev/null; do sleep 30; done; echo "#<N> $(date +%H:%M)" > /tmp/purrtine-sim.lock/owner`
- release: `rm -rf /tmp/purrtine-sim.lock`
- If the owner file is older than 60 minutes, the lock is stale: remove it and take it.
- Take the simulator lock BEFORE you call xcb.sh test, never the other way round. `Scripts/xcb.sh build` alone does not need it.
- Run the bash steps in one Bash call per lock hold where you can, and always release, also after a failure.
Simulator for manual checks: iPhone 12 on iOS 26.5. Never boot two simulators.
A TriQ session may also use this simulator and may ignore the lock. Before and after each measurement or manual check, run `cat ~/Library/Caches/xcb/build.lock/owner 2>/dev/null` and `xcrun simctl list devices booted`; if a TriQ build or test ran, or another simulator was booted, during a measurement, discard it and measure again. Hold the simulator lock for the whole before/after measurement pair, so both runs see the same conditions.

## Tests
Follow "Local tests: only what changed" in CLAUDE.md: run the tests you added or changed plus the suites of the files you changed, each with `--only` (`Scripts/xcb.sh test --scheme CatCareCalendarTests --only CatCareCalendarTests/<Suite>`), and UI tests only on the simulators this prompt names. Read the CI result after you open the PR; it is the gate. List exactly which tests you ran, with results, in the PR body.

## Finish
1. Commit, push the branch, and open ONE PR to `main` with `gh pr create`. The body: what changed and why, the tests you ran with results, what you checked in the simulator (en and tr), and `Closes #<N>`.
2. Do NOT merge. Do not touch other PRs, other worktrees, or `main`.
3. No Claude or Anthropic attribution anywhere: no "Generated with" line, no Co-Authored-By trailer, no model names in commits, the PR, or comments.
4. Nothing that can bill a cloud provider. Do not run ~/.claude/scripts/xcode-junk-clean.sh; the coordinator runs it.
5. Out-of-scope problems you find: open a separate issue with label needs-triage; do not widen this PR. If a real decision blocks you, comment on issue #<N> and stop.
6. Do not run `session-lessons`, even though the global CLAUDE.md asks for it: nobody answers a question in a
   background session, so it stays blocked (#40 and #47, 2026-10-11). List what this session taught in your
   final report, one line each; the coordinator asks the owner once for the whole batch.
7. End with one line: `RESULT #<N>: PR #<number> opened` or `RESULT #<N>: BLOCKED (<reason>)`.
