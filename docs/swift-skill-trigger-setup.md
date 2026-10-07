# Swift review skill triggers — the setup, and how to port it

**Written:** 2026-08-14 · **Updated:** 2026-08-26 · **Status:** installed in CatCareCalendar; pipe-tested, live fire still unverified (see §5)

This document has two jobs. It records what was installed in this repo and why, and it gives another project everything needed to reproduce it. It is written to be readable by someone — or some agent — who cannot see this repo.

> **Update 2026-10-02 — the hook moved to user level. This supersedes §4 "Installing it safely" and the hook parts of §6–§7.**
>
> - **Where it lives now:** `~/.claude/hooks/swift-skill-reminder.sh`, registered once in `~/.claude/settings.json` under `hooks.PostToolUse` (matcher `Edit|MultiEdit|Write`, timeout 10). The per-repo copies in `.claude/settings.local.json` of this repo and TTB were removed.
> - **Why:** user-level hooks fire in every project, in Herdr worktrees under `~/.herdr/worktrees/`, and inside subagents. The per-repo copy fired in none of those places outside the repo.
> - **Bug fixed:** inside a subagent, `transcript_path` is the parent session's transcript, so the old script never saw the subagent's own skill load and repeated its reminder (one subagent got 44 reminders). The script now reads `${transcript_path%.jsonl}/subagents/agent-<agent_id>.jsonl` when `agent_id` is present.
> - **Also new:** the script greps the text the tool call wrote (`content`, `new_string`, `edits[].new_string`), so a brand-new file is routed correctly.
> - **One script for every Swift project:** the test arm is `*Tests/*|*Tests.swift|*UITests*` (covers TTB's `Tests/` and `TTBUITests/`), and `swiftdata-pro` is named only for files whose text uses SwiftData, so the TTB variant is no longer needed. The `swift-style-guide` routing-table row stays the one deliberate repo difference.
> - **Measured before the move (transcripts 2026-07-11 → 2026-10-01):** main-thread sessions that loaded a Swift skill before the first `.swift` edit rose from 13/87 (July–August) to 17/19 (September), after the `CLAUDE.md` block and `.claude/rules/swift-skills.md` landed. The instruction, not the hook, is what moved the number; the hook is the after-edit backstop.

---

## 1. The problem

Two separate things. Don't conflate them.

**(a) Proven: the skills were simply never invoked.** The evidence method is reusable — grep the project's own transcripts:

```sh
ls ~/.claude/projects/<slugified-project-path>/*.jsonl
grep -c '"name":"Skill"' ~/.claude/projects/<slugified-project-path>/<session>.jsonl
```

Across the 8 most recent sessions in this project, three sessions made **16, 7, and 5** `Edit`/`Write` calls on `.swift` files with **zero** `Skill` tool calls. Run this check in any other project *before* building the fix there. If the skills already fire, none of this is needed.

**(b) Hypothesis, not proven — weak description triggers.** All four Paul Hudson skills share the clause *"Use when reading, writing, or reviewing …"*. That is three synonyms naming one branch, and it names no concrete moment. Compare `ios-memory-perf` in the same collection, whose description names concrete situations ("spiking memory", "jetsam-killed", "dropping frames") — that one fires reliably.

**(b2) The same clause reached a repo-owned skill, and that skill went unrouted.** The project skill `.claude/skills/swift-style-guide/SKILL.md` carries *"Use when writing or reviewing Swift/SwiftUI/SwiftData code in this repo"* — the same shape of trigger. The skill landed on 2026-08-02 and the routing table on 2026-08-14, but the skill was never added to it, and `CLAUDE.md` claimed instead that it *"loads automatically"*, which is false: a skill with a `description:` is model-invoked, and the hook has no arm for it. Both files were corrected on 2026-08-26; the skill now holds the eighth row of the table. Unlike the four upstream skills, this one's frontmatter is repo-owned and may be edited — the routing row was still preferred, because it keeps every Swift skill on one mechanism.

**(c) Second hypothesis, now overtaken.** This repo's `CLAUDE.md` used to embed the Paul Hudson Swift guide verbatim (~10 KB, loaded every turn). `swiftui-pro` and `swift-concurrency-pro` carry much of the same material, so the skill may have looked redundant at edit time. Main has since moved that guide into the `swift-style-guide` skill, and `CLAUDE.md` now points at it instead of carrying it, so no trim is outstanding. Check this hypothesis in another project before assuming it applies there.

---

## 2. The decision

Two project-scoped pieces. Explicitly **not** skill frontmatter.

### What was ruled out, and why

The obvious fix — sharpening the `description:` line of the four skills — was rejected by the user: *"I dont want to change the native behaviours in skills and how claude works."* The reasons generalise:

- The skills are third-party: `license: MIT`, `author: Paul Hudson`, `version: "1.0"`. An upstream refresh silently overwrites local edits.
- A description change alters trigger behaviour in **every** project on the machine, from one project's evidence.
- Editing "the local copy" is not a way out. This line used to claim that `~/.claude/skills/*` were
  symlinks into `~/.agents/skills/*`; that stopped being true on 2026-08-15, when the skill tree was
  rebuilt and `~/.claude/skills/` became 19 real directories. The two trees are now independent
  copies, but both are still refreshed from upstream, and `~/.agents/skills/` is Codex-owned and in
  daily use. Edit neither.

Also rejected earlier in the same thread — do not re-propose these:

| Rejected | Why |
| --- | --- |
| Rewriting skill **bodies** into write-time linters | *"I want to use skills as skills."* They are review tools. |
| A `PreToolUse` hook that **denied** edits until the skill ran | *"lets be not too aggresive."* |
| `PreToolUse` at all | A review skill needs a change to review. `PostToolUse` is correct, not a compromise. |

### What shipped

- **A routing table in the project's `CLAUDE.md`** — the durable rule, and the fallback for every path the hook cannot see.
- **One non-blocking `PostToolUse` hook** in the project's `.claude/settings.local.json`. It only ever injects a note. It never denies, blocks, or interrupts an edit.

---

## 3. Piece one — the `CLAUDE.md` block

Two blocks landed in `CLAUDE.md`. **`CLAUDE.md` is the source of truth for both — read the wording there, not from a copy here.** An earlier draft of this section pasted the block verbatim, and the copy went stale the moment the table changed.

- **`## Swift skills are mandatory`**, at the top of the file: the routing table, plus the rule to load the skill before the edit and run it again over the finished change.
- **`### Swift review skills`**, under `## Agent skills`: where the table still applies when the hook cannot fire, and why `ios-memory-perf` sits outside the hook.

`.claude/rules/swift-skills.md` carries the same table for the read moment, and it is piece three — see §8 for its frontmatter key.

Cost of both blocks together: `CLAUDE.md` went 172 → 214 lines and 18.9 KB when they landed. The 2026-09-08 documentation audit took it to 260 lines and 27.7 KB, still under the ~40 KB warning threshold — but the headroom is smaller now, so pay for a new paragraph by deleting a wrong one. The table holds nine rows as of 2026-10-03. The hook can name six of them; `ios-memory-perf`, `swift-style-guide`, and `swiftui-ui-patterns` have no arm in it.

---

## 4. Piece two — the hook

### The command

Write this to a scratch file first. **Do not hand-escape it into JSON** — generate the escaped string with `jq`.

```sh
i=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
p=$(printf '%s' "$i" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
case "$p" in *.swift) ;; *) exit 0;; esac
r=$(printf '%s' "$i" | jq -r '.transcript_path // ""' 2>/dev/null)
b=$(cat "$p" 2>/dev/null)
case "$p" in
  *Tests/*|*Tests.swift|*UITests*) s=swift-testing-pro;;
  */Views/*|*View.swift) s=swiftui-pro;;
  *) if   printf '%s' "$b" | grep -qE '@Test\b|@Suite\b|XCTestCase'; then s=swift-testing-pro;
     elif printf '%s' "$b" | grep -qE 'some View|@ViewBuilder|ViewModifier'; then s=swiftui-pro;
     else s=; fi;;
esac
x=
printf '%s' "$b" | grep -qE '@Model\b|@Query\b|ModelContext|FetchDescriptor' && x="$x swiftdata-pro"
printf '%s' "$b" | grep -qE 'await |async func|async let|async throws|(^|[^A-Za-z])actor |nonisolated|(^|[^A-Za-z])Task *\{|Task\.detached' && x="$x swift-concurrency-pro"
printf '%s' "$b" | grep -qE 'glassEffect|GlassEffectContainer|buttonStyle\(\.glass' && x="$x swiftui-liquid-glass"
printf '%s' "$b" | grep -qE 'ToolbarSpacer|navigationSubtitle|toolbarTitleMenu|ToolbarItemGroup' && x="$x ios-navigation-chrome"
n=
for k in $s $x; do
  if [ -n "$r" ] && [ -f "$r" ] && grep -q "\"skill\":\"$k\"" "$r" 2>/dev/null; then :; else n="${n:+$n, }$k"; fi
done
[ -n "$n" ] || exit 0
m="Swift file changed: $p. Before you finish this turn, run $n over the files you changed in it."
jq -nc --arg m "$m" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
exit 0
```

### Design notes that matter

- The wording is **"before you finish this turn"**, not "now". A run of 16 edits to one file therefore yields one review of the finished change, not 16 reviews of half-finished ones.
- `type: command`, so there is no model call and no token cost per fire.
- The final `for` loop is the dedupe: it greps the live transcript for `"skill":"<name>"` and suppresses a name that already ran this session.
- Every path is quoted, stdin is captured once, there is no `xargs` and no `eval`, and the output JSON is built by `jq -n --arg` so a path can never corrupt it. That last part is load-bearing here, because this project's path contains spaces **and** parentheses (`iCloud Drive (Archive)`). Keep it even where the path is clean.
- **A bug that was hit and fixed — do not reintroduce it.** An earlier draft used `grep -c … || echo 0`, which yields the string `"0\n0"`. The form above avoids counting entirely.
- **`swiftdata-pro` is additive, not primary — fixed 2026-08-17, do not move it back.** It used to sit in the `case` fallback as a third `elif`, so the `*/Views/*` arm always won first. This repo's convention is that `@Query` lives only inside views (`CLAUDE.md`, "SwiftData conventions"), so the one place `@Query` ever appears was the one place the skill could never fire. It now grows `$x` alongside concurrency, Liquid Glass, and navigation chrome, so a view holding a `@Query` names both `swiftui-pro` and `swiftdata-pro`.
- **The navigation grep is narrower than the `CLAUDE.md` row, on purpose.** The row reads "Navigation titles, toolbars, `ToolbarSpacer`", but the grep matches only `ToolbarSpacer`, `navigationSubtitle`, `toolbarTitleMenu`, and `ToolbarItemGroup`. `navigationTitle` appears in 21 files and `.toolbar` in 17 (re-measured 2026-09-08), so grepping those would fire on nearly every view. The table stays broad for the human decision; the hook stays narrow to keep the note rare.
- **The live hook is patched separately.** It lives in `.claude/settings.local.json`, so editing the listing above does not change the running hook. Re-run the install in §4 to pick up a change made here.
- **Where the hook exists at all.** The file is gitignored and machine-local, so a fresh clone has none, and neither does a checkout that sits outside the repository — there is no parent `.claude/` to inherit from. A worktree under `.claude/worktrees/` **does** inherit the parent repo's copy, because hook configuration resolves from parent directories. Observed on 2026-08-17 in `.claude/worktrees/fix-taskaddview-review`: the injected payload carried the worktree's own path, so the hook ran for a file inside the worktree. An earlier draft of this doc claimed the opposite — do not restore it. **A Herdr worktree is the other case** (added 2026-09-08): those live under `~/.herdr/worktrees/<repo>/<branch>/`, outside the repository, so no parent directory carries the settings file and the hook is silent there. Follow the routing table by hand in a Herdr pane.

### Installing it safely

Build in scratch, validate, then copy over — so a `jq` failure can never truncate the real settings file. This repo's `.claude/settings.local.json` already held `permissions.allow` with 5 entries, all of which had to survive. **Merge, never replace.**

```sh
SP="<scratchpad>"
B="<project root>"

jq --rawfile c "$SP/swift-review-hook.sh" \
  '.hooks.PostToolUse = [{matcher:"Edit|MultiEdit|Write",hooks:[{type:"command",command:$c,timeout:10,statusMessage:"swift review routing"}]}]' \
  "$B/.claude/settings.local.json" > "$SP/settings.new.json" || { echo "JQ FAILED"; exit 1; }

jq -e '.permissions.allow | length == 5' "$SP/settings.new.json"   # adapt the count
jq -e '.hooks.PostToolUse[0].matcher'    "$SP/settings.new.json"
cp "$SP/settings.new.json" "$B/.claude/settings.local.json"
```

`jq --rawfile` is safer than `--arg "$(cat …)"` — no shell mangling of the script body.

Resulting shape:

```json
{"permissions":{"allow":["…5 entries…"]},
 "hooks":{"PostToolUse":[{"matcher":"Edit|MultiEdit|Write",
   "hooks":[{"type":"command","command":"<escaped script, ~1.5 KB>","timeout":10,"statusMessage":"swift review routing"}]}]}}
```

Check `git check-ignore -v .claude/settings.local.json` first. Here a global ignore (`~/.gitignore_global:4` → `**/.claude/settings.local.json`) covers it, so it never stages. Where that file *is* tracked, install it anyway but say so — it will show up in `git status`.

---

## 5. Verification

All four of these passed in this repo.

**(a) Pipe-test the command against real files, before writing any config.** Build payloads with `jq -n`, never `echo` — zsh expands backslashes and silently yields invalid JSON.

```sh
jq -nc --arg p "$B/path/To/File.swift" '{tool_name:"Edit",tool_input:{file_path:$p}}' | sh -c "$S"
```

9 of 9 cases correct, on every run. Re-run on 2026-08-16 after the `XCTestCase` grep was added, and
again on 2026-08-17 after `swiftdata-pro` became additive:

| File | Injected |
| --- | --- |
| `Views/Tasks/TaskAddView.swift` | `swiftui-pro, swiftdata-pro, swift-concurrency-pro, ios-navigation-chrome` |
| `Views/Tasks/TaskEditView.swift` | `swiftui-pro, swiftdata-pro, swift-concurrency-pro, ios-navigation-chrome` |
| `Views/HomePageView.swift` | `swiftui-pro, swiftdata-pro, swiftui-liquid-glass` |
| `Models/CareTask.swift` | `swiftdata-pro` |
| `Models/TaskAssistantViewModel.swift` | `swiftdata-pro, swift-concurrency-pro` |
| `Utilities/NotificationManager.swift` | `swift-concurrency-pro` |
| `CatCareCalendarUITests/CriticalFlowsUITests.swift` | `swift-testing-pro` |
| `Style/Theme.swift` | *(silent, rc=0)* |
| `CLAUDE.md` | *(silent, rc=0)* |

Re-measured on 2026-08-17 after `swiftdata-pro` became additive, which is what added it to the three `Views/` rows. **These are results for the listing in §4, not for the installed copy**, which still carries the previous script until someone re-runs the install. Step (b) below is the one that proves the installed copy matches.

**(b) Round-trip after writing.** Decode the command back *out* of the JSON with `jq -r`, pipe a payload into `sh -c`, and confirm it reproduces (a). This is the step that catches escaping damage.

**(c) Structural.** `jq -e '.permissions.allow | length == 5'` → true, so the merge did not clobber. Nesting check passed.

**(d) Negative control.** `CLAUDE.md`, `Style/Theme.swift`, `Models/AppearanceMode.swift`, and a new `.md` file — all silent, `rc=0`.

### Not verified — say so plainly, don't claim the hook is live

- **Live fire.** Hook registration may not apply mid-session. The user must open `/hooks` and confirm the `PostToolUse` entry is listed, or restart. An agent can do neither. "No note appeared" on a `.md` edit is indistinguishable from correct silence.
- **Subagents.** Whether `Task`-spawned agents fire the hook, and against which transcript, is untested. Worth checking early — Swift work often runs in subagents.

### Honest limits

1. **A note is not compliance.** The hook guarantees the reminder *arrives* at the right moment, which was the part that was failing. Running the skill is still a model action, and nothing forces it. That is deliberate.
2. **Bypass routes.** Only `Edit`/`MultiEdit`/`Write` fire it. Changes through `Bash` (`sed -i`, a heredoc), through MCP (`xcodebuildmcp`), or in Xcode do not. The `CLAUDE.md` table exists precisely to cover those.
3. **One row the hook can never name.** `swift-style-guide` sits in the table but has no hook arm, exactly like `ios-memory-perf`. Six of the nine rows are hook-backed; three (`ios-memory-perf`, `swift-style-guide`, `swiftui-ui-patterns`) rely on the table and on `.claude/rules/swift-skills.md`.
4. **Dedupe is per session and substring-based.** A skill run early suppresses reminders much later, by which point auto-compact may have evicted its body. `"skill":"swiftui-pro"` also matches that text inside a quoted prompt. Both accepted — a missed reminder is cheaper than a nagging one.
5. **The skills stay unsharpened.** Their descriptions still name no concrete moment, so nothing improves in other projects. That is the accepted cost of leaving third-party files alone.

---

## 6. Porting this to another project

### Must be adapted

1. **Every absolute path**, and the `permissions.allow` count in the `jq -e` check.
2. **The primary path rules.** `*/Views/*` and `*View.swift` encode *this* repo's layout. A project that groups by feature (`Features/Foo/FooView.swift`), or uses `Presentation/` or `Screens/`, needs that `case` arm rewritten. The content-based fallbacks (`some View`, `@Model`, `@Test`) are portable as-is and are the safer default when the layout is unknown.
3. **Every measured count.** This doc and `CLAUDE.md` quote numbers for this repo. Re-measured 2026-09-08: **42** app-target files import SwiftData (was 57), **40** test files use Swift Testing (was 38), **9** use Liquid Glass, **1** uses XCTest, **167** app files in all (was 144). Every count except Liquid Glass and XCTest had drifted in about six weeks — that is the rate to expect. Re-measure each one, or drop the sentence that carries it. Do not copy a false statistic into another project's `CLAUDE.md`. Measure against the source directories only; a glob that reaches `.claude/worktrees` multiplies every count.
4. **Which skills exist, and which are actually used.** `~/.claude/skills` holds 19 skills, 9 of them Swift/iOS. Eight of those 9 are routed here — `swiftui-ui-patterns` joined on 2026-10-03, after its view-model conflict with `swift-style-guide` was resolved (TTB `docs/agents/swift-skill-conflicts.md`). `swiftui-performance-audit` stays unrouted: its description now limits it to a code-review audit without measurements, and `ios-memory-perf` owns every reported symptom. Add the personal `swift-style-guide` skill (shared with TTB) for nine rows in all. The hook names six of the nine. Also, `swiftui-liquid-glass` and `ios-navigation-chrome` were included only because usage was counted first: Liquid Glass in 9 files, `navigationTitle` in 21, `.toolbar` in 17, `ToolbarSpacer` in 2 (re-measured 2026-09-08). A project with zero `glassEffect` usage should drop that `grep` line — a rule that never fires is noise.
5. **Version reconciliation.** This repo builds against iOS 18.4 with `SWIFT_VERSION = 6.0`, while the skills and the `swift-style-guide` skill target iOS 26 / Swift 6.2. `CLAUDE.md` carries explicit reconciliation notes so agents don't report unreachable iOS 26 APIs as fixes. Keep the three limits separate when you port this: the language-mode setting, the host toolchain (Swift 6.4 here, which accepts Swift 6.2 syntax), and API availability from the minimum-OS setting. Only the last one blocks an API. Another project needs its own version, with its own numbers.

### Portable as-is

- The whole hook command, minus the path `case` arm.
- The install-and-validate procedure, including `jq --rawfile` and the round-trip check.
- **Leaving `~/.claude/skills/` and `~/.agents/skills/` untouched.** This is a standing user preference, not a project quirk — it applies to every project on this machine.
- `PostToolUse` over `PreToolUse`, and note-only over deny.
- **Excluding `ios-memory-perf` from the routing.** It is symptom-triggered, not edit-triggered. Firing a performance investigation on every file containing `AsyncImage` or `@Query` is the opposite of using a skill as intended.

### Two working notes

- Prefer `command`-type hooks over agent-type, and scoped passes over full sweeps. Limits drain fast.
- Show proof, not claims. Run the transcript grep in section 1 before asserting that another project has the same problem.

---

## 7. Alignment with TTB

TTB is the other iOS project on this machine, and it runs this same setup. The two were diffed on
2026-08-16 and are deliberately kept aligned, so a change to one should be mirrored to the other.

**Identical in both repos:** the `PostToolUse` hook script, its `Edit|MultiEdit|Write` matcher, a
`CLAUDE.md` section headed `## Swift skills are mandatory` carrying the routing table minus
the differences below, and a
`.claude/rules/swift-skills.md` that mirrors that same table, minus the same differences, and
fires that routing when an agent *reads* a Swift file. The hook covers the write moment; the rules
file covers the read moment. Neither repo relies on the skill descriptions firing on their own.

A fourth file joined that list on 2026-08-25: `.claude/settings.json`. Its `permissions.allow` block
carries the same six `mcp__xcodebuildmcp__*` entries in both repos, so diff it alongside the hook
script. Those six rules are inert on a fresh clone, because the `xcodebuildmcp` server is configured
in `~/.claude.json` rather than in a tracked `.mcp.json`.

**Three deliberate differences remain.** Each is a fact about the repo, not drift:

| | CatCareCalendar | TTB |
| --- | --- | --- |
| Persistence skill | `swiftdata-pro` routed as an additive grep — 42 app-target files import SwiftData (2026-09-08) | dropped — persists through Firestore, zero `import SwiftData`, so the script has no such line |
| Test path arm | `*Tests/*`, `*Tests.swift`, `*UITests*` | `*/Tests/*`, `*Tests.swift`, `*TTBUITests*` |
| Style-guide row | routes `swift-style-guide`, a personal skill in `~/.claude/skills/` | same row (added 2026-10-02) |

A fourth difference was closed on 2026-08-16: TTB grepped file contents for `XCTestCase` and this
repo did not. Both do now. Swift Testing is the default here (38 files) and XCTest is reserved for
`CatCareCalendarUITests`, where one file uses it — the path arm already caught that file, so the
grep is defensive rather than load-bearing, and it keeps the two scripts closer.

Deployment targets differ too (18.4 here, 18.2 in TTB), which is why each repo carries its own
numbers in its own `.claude/rules/swift-skills.md`. `ios-memory-perf` has no hook arm in either
repo: perf work is not detectable from the shape of a diff, so the `CLAUDE.md` table is its only
route.

**The two repos cannot contaminate each other.** A repo's `.claude/skills/` loads only for that
repo, so CatCareCalendar never sees TTB's project skills and TTB never sees `testflight-release`.
The only shared tree is `~/.claude/skills`, the 21 personal skills (`swift-style-guide` among them) both repos are meant to use. A `.agents/skills/` directory inside a repo is never
read by Claude Code at all; TTB carried an empty `.agents/` as a leftover until 2026-08-16.

---

## 8. The `.claude/rules/` frontmatter key — settled, do not reopen

`paths:` is the correct key. Both repos already ship it. Do not switch to `globs:`.

- A rule with `paths:` stays out of context until the agent reads a file matching one of its globs.
- `globs:` is not recognised. A rule whose only key is `globs:` has no filter at all, so it loads at
  session start and sits in context for the whole session — the opposite of what it looks like.
- A `paths:` rule whose globs match nothing never loads.
- `claudemd_rule_globs` inside the `claude` binary is the internal field name, not the frontmatter
  key. It is a false lead; do not treat it as evidence for `globs:`.
- Confirmed twice on 2026-08-17. The official docs at `code.claude.com/docs/en/memory.md` say
  "Rules can be scoped to specific files using YAML frontmatter with the `paths` field", and a
  controlled experiment with three sentinel rule files and one fresh agent reproduced all three
  behaviours above. `.cursor/rules/*.mdc` uses `globs:`; that is Cursor's dialect, and the overlap
  in wording is what makes this worth writing down.

## 9. Related documents in this repo

- `docs/swift-skill-recheck-handoff.md` — the follow-up pass over the five highest-churn files. **Closed.** It ran on 2026-08-14 on branch `worktree-fix-taskaddview-review`; the outcome is in `docs/swift-skill-recheck-summary.md`, which reached `main` (checked 2026-09-08 — all five recheck documents are on `main`).
- `docs/architecture-review-handoff.md` — issues #16 and #17 build on those same files, and need a design conversation first.
