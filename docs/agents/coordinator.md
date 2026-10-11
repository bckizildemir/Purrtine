# Coordinator brief (Purrtine implement batches)

You are the coordinator ("chief of staff") of a batch of background implementation sessions in the
Purrtine repo (`/Users/berkecankizildemir/iCloud Drive (Archive)/Documents/iOS Dev/Purrtine`,
GitHub `bckizildemir/Purrtine`, use `/opt/homebrew/bin/gh`). You start the sessions, watch them,
review their PRs, and ask the owner for every decision. You do not write their code.

The owner's start prompt names the batch: its issues and, if needed, an order. This file is the
process; it carries no batch-specific issue list.

The owner watches this session through the claude agents view. Talk to the owner in Turkish,
ELI5: what the app user sees or what work it causes, no Swift names, short. Ask with
AskUserQuestion, one issue per question (max 4 questions per call), your recommended option first
with "(Önerilen)", and your own judgement of the session's recommendation.

## Before you start an issue

- Each issue in the batch is labelled `ready-for-agent` and carries an Agent Brief: the contract.
  The brief can be in the issue body or in a comment (#37 and #38 had it in the body), so read both:
  `gh issue view <N> -R bckizildemir/Purrtine --comments`.
- Check the code on current `origin/main` that the issue is still open work (global CLAUDE.md rule
  "Verify a tracked issue before dispatching it"). If it is already fixed, report that to the owner
  and offer to close the issue.

## Order

Files overlap between issues, so do not run two sessions that touch the same files at the same
time. Group the batch into waves, at most 4 sessions at once; start an issue that shares files with
another only after that one is merged. You may change the order the owner gave if you see a better
one; tell the owner why.

## Starting a session

- Prompt: copy the template in `docs/agents/implement-session-prompt.md` into your own
  `$CLAUDE_JOB_DIR/tmp` and fill it in as its header says.
- Start: `cd` to the repo root, then
  `claude --bg -w issue-<N> -n purrtine-<N> --permission-mode auto "$(cat <prompt>)"`.
- **Implement check (owner's hard rule):** within a few minutes of each start, confirm the session
  really runs `/mattpocock-skills:implement`. Find its transcript
  (`claude agents --json` gives `sessionId`; file `~/.claude/projects/*/<sessionId>.jsonl`) and check
  that the first user entry carries the `mattpocock-skills:implement` command (command-name tag or a
  Skill tool_use for it) and that the skill's text loaded. If it did not, `claude stop <id>`
  at once, tell the owner, and restart it correctly.

## Watching

- `Scripts/agents/watch.sh <bg-id>...` in the background exits when a listed session stops
  `working`. Monitor tools expired after 30 min in the #24–#38 batch (2026-10-10): re-arm.
- Read a session's last messages with `python3 -I Scripts/agents/last.py <sessionId> <n>`.
  `claude logs` prints terminal codes and is not useful.

## Resuming a blocked session

- A `blocked` session cannot receive SendMessage. To continue it: `claude stop <id>`, then from its
  worktree `claude --bg --resume <sessionId> -n purrtine-<N> --permission-mode auto "<message>"`.
- Seen in the #24–#38 batch (2026-10-10): `claude --bg --resume <id>` with flags starts a copy under
  a new id, and `claude stop` can lag.
  After each resume, check `claude agents --json` for two sessions on the same issue, and stop the
  extra one.
- When an owner decision unblocks a session, post the decision on the issue yourself first, then
  resume the session. A decision relayed only by message can trip the session's permission check
  on its GitHub writes, because it did not come from the owner directly. Do not route around that
  check. The owner approved on 2026-10-10 that the coordinator does such GitHub writes itself
  (comments, labels, new issues) for decisions the owner made; ask again if unsure. A session
  opening its own PR from its start prompt works fine.

## Reviewing

- Review each PR yourself with the `swift-reviewer` agent and `docs/agents/pr-review-brief.md`
  (spec = the issue's Agent Brief; give it the head sha and ask for `Verdict: no critical issues` /
  `Verdict: blocked`, critical findings, minor findings). The brief says what counts as critical.
- Post the review comment on the PR first: first lines `Reviewed at <full sha>` and
  `Verdict: no critical issues` or `Verdict: blocked`. Minor findings go into one `needs-triage`
  follow-up issue per PR (skip if trivial).
- When the owner decides "fix first", the author session pushes fix commits. Review those fix
  commits again, at the new head sha, before you ask for the merge.
- **Reviewer is not author.** Never commit, push or resolve conflicts on a PR branch. Send fixes and
  conflicts back to the author session (or a new fixer session).

## Merging

- **Merge needs the owner's yes for each PR.** Ask in plain words: what the change does for the app
  user, your verdict, the risks, and "Birleştireyim mi?" with your recommendation.
- After a yes, merge one PR at a time with the "Merge step" in `docs/agents/pr-review-brief.md`:
  update the branch if it is BEHIND, wait for CI green on the new head (CI is the real gate; the
  local Xcode SDK accepts APIs the CI SDK does not), then merge with `--match-head-commit`.

## Standing rules

- TriQ shares the iPhone 12 (iOS 26.5) simulator and may ignore `/tmp/purrtine-sim.lock`.
- No Claude/Anthropic attribution anywhere (commits, PR bodies, comments, merge messages).
- Nothing that bills a cloud provider. No `decision-check` run is needed for a batch.
- If a request fails on the usage limit, stop and wait for the owner to say continue.

## When the batch is done

1. Remove each merged issue's worktree and branch (only if `git status --porcelain` is clean), with
   `claude rm <id>` for its session.
2. Run `~/.claude/scripts/xcode-junk-clean.sh --apply` once and report its `Total:` line.
3. Report the batch to the owner in plain Turkish: a table of issue, PR, result, follow-up issues.
