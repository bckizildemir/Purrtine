# PR review brief (Purrtine)

The coordinator (`docs/agents/coordinator.md`) gives this brief to each review session, or to its
own `swift-reviewer` agent, with the PR number, branch, issue, and worktree.

You review ONE open PR in `bckizildemir/Purrtine`. Your PR number, branch, issue, and worktree are in
your prompt. The repo root is `/Users/berkecankizildemir/iCloud Drive (Archive)/Documents/iOS Dev/Purrtine`
(your cwd). Use `/opt/homebrew/bin/gh` if `gh` is not on PATH.

## 1. Review

Invoke the `code-review` skill and follow it exactly.

- Fixed point: `origin/main`. Run `git fetch origin` first. Do the diff and log from the PR worktree
  (`git -C <worktree> diff origin/main...HEAD`), or from refs: `git diff origin/main...origin/<branch>`.
- Spec: the linked issue (`gh issue view <N> -R bckizildemir/Purrtine --comments`) plus the PR body.
- Standards sources: `CODING_STANDARDS.md`, `CLAUDE.md`, `.claude/rules/*.md`.
- The skill spawns two sub-agents. Pass `model: "sonnet"` to both.
- Do not build or run tests. CI (`.github/workflows/ci.yml`) is the gate. Start the review while CI is still
  pending; the coordinator checks the CI result before the merge. The `ui-tests` job runs the UI
  tests in CI (newest iOS runtime only); the author runs locally only the UI tests they added or
  changed (see "Local tests: only what changed" in CLAUDE.md), and the PR body lists them. Another agent may hold
  the build lock.

## 2. Decide

A **critical** finding is one of these:
- a wrong behaviour or regression a user can hit (data loss, a crash, a lost reminder, a wrong save),
- a requirement in the issue that is missing or implemented wrong,
- a broken binding repo rule from CLAUDE.md (for example a care-task save outside `CareTaskWriting`,
  a direct `UNUserNotificationCenter.current()` outside `Utilities/`, an edit to schema V1,
  a user-facing string not in `Localizable.xcstrings` with en + tr),
- a change that hands off between alerts, sheets, or a disappearing view, and the PR names no check
  with animations on (`-ui-testing -keep-animations`, see "Animations-off blind spot" in
  `.claude/rules/testing.md`). `-ui-testing` turns animations off, so UI tests alone never see such
  a race; #27 and #31 hid there. Ask the author for that check.

Style smells, naming, and judgement calls are NOT critical.

## 3a. No critical finding: report ready to merge

You do NOT merge. The user merges, one PR at a time, or tells a session in their own message to merge.

Label each finding with one of: `critical`, `blocker`, `severity: high` (these block the merge), or
`minor`, `judgement` (these do not).

1. Record the head commit you review: `gh pr view <N> --json headRefOid --jq .headRefOid`.
2. Post the full review as one PR comment, inline (`gh pr comment <N> --body "<report>"`). Put these two
   lines at the top: `Reviewed at <sha>` (the full sha from step 1) and `Verdict: no critical issues`.
3. Non-critical findings worth doing later: open ONE follow-up issue that lists them, with label
   `needs-triage`. Skip it if the findings are trivial.
4. Do not update the branch, merge, or remove the worktree. The merge step does that.

## 3b. Critical finding: do not merge

Post the review inline (`--body`) as a PR comment, with `Reviewed at <sha>`, `Verdict: blocked`, and
the blocking findings at the top. Report and stop.

## Merge step (only when the user's own message asks for it)

Merge one PR at a time. For each PR, in order:
1. `gh pr view <N> --json mergeStateStatus,headRefOid`. If `BEHIND`: `gh pr update-branch <N>`, then
   `gh pr checks <N> --watch`, and confirm that the only new commit is the merge from `main`; merge
   at that new head sha. If `DIRTY`: stop; a fixer session resolves it and a different session
   reviews the resolution.
2. `gh pr merge <N> --squash --match-head-commit <sha> --delete-branch --subject "<subject> (#<N>)" --body "<2-4 lines, Closes #<issue>>"`
3. Clean up the worktree from the repo root: `git worktree unlock <worktree>`, `git worktree remove
   <worktree>` (stop and report if it holds real uncommitted source changes), `git branch -D <branch>`.

## Rules

- You are the reviewer, not an author. Never commit to, push to, or resolve a conflict on the PR's
  branch. `gh pr update-branch` is the only change you may make to it. If the PR needs a code change
  (a fix or a conflict resolution), post your review, go to 3b, and report it. Another
  session makes the change, and a third session reviews it.
- No Claude or Anthropic attribution anywhere: no "Generated with" line, no Co-Authored-By trailer,
  no model names in comments, issues, or merge messages.
- Do not touch other PRs, other worktrees, or `main` directly.
- Nothing that bills a cloud provider.
- Finish with a short final message in this form:
  `RESULT PR #<N>: READY TO MERGE | BLOCKED (<reason>) — reviewed at <short sha> — standards: <n> findings, spec: <n> findings — worst: <one line> — follow-up issue: <#n or none>`
