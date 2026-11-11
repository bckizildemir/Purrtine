# Stage 2 run: who builds what, and where to resume

Started by the owner on 2026-11-11. Two background sessions start at 05:12 (+03), after the 5-hour limit resets.
Decisions: [stage2-polish-decisions.md](stage2-polish-decisions.md). Audit: [animation-audit.md](animation-audit.md).

## Where progress lives

- **Each issue's GitHub comments.** A session posts one comment per step: `Step <n> done: <what>, <commit or PR>`.
  To resume, read the issue's last comment and continue from the next step.
- Each issue gets its own branch and PR. A PR that needs an unmerged earlier PR branches from it and says so in its body.

## Sessions

| Session | Issues, in order | Why this order |
|---|---|---|
| `stage2-motion` | #124 motion tokens → #125 no glass + press shrink → #127 onboarding fade | #125 and #127 use the tokens from #124 |
| `stage2-calendar` | #126 Apple calendar + dots → #128 Whiskers cat placeholder → #129 Whiskers chat animation | #128 puts the cat in the calendar's empty state |
| later | #130 Reduce Motion, haptics, cleanup | It touches every file above; start after both chains merge |

## Steps per issue (Matt Pocock's skills, from `ask-matt`)

The issues came out of a grilling round and a prototype, so they are tickets already: no `/triage`, no `/to-spec`.

1. Read the issue, the decision it names, and the code it points to. Check `origin/main` first: if it is already done, comment so and skip.
2. **`/implement`** (read `~/.claude/plugins/cache/claude-plugins-official/mattpocock-skills/1.3.1/skills/engineering/implement/SKILL.md`
   and follow it; it cannot be called with the Skill tool). Swift edits go through a `swift-writer` subagent.
3. **`/tdd`** at each seam that has logic: #124 the Reduce Motion fallback, #126 the pure dots-per-day function (open/done,
   order, cap of 3), #127 the direction for `go(to:direction:)`. Pure visual changes (#125 surfaces, #128 shapes) get no
   forced test.
4. **`/codebase-design`** only for #126 (the calendar wrapper's interface: SwiftUI → `UICalendarView` seam).
5. **`/code-review`** on the branch, plus one `swift-reviewer`.
6. **verify-purrtine** through `sim-verifier`: drive the changed screens as a real user, with animations on, and with Reduce
   Motion on where the issue names it. Never ask the owner to test.
7. **`/pr`** for the PR body: before/after screenshots from step 6, the tests run, and the door call.
8. After the last issue of the chain: **`/retro`** (read its SKILL.md by path and follow it). Write the proposals in the
   chain's last PR; the owner says yes before any of them lands.

https://claude.ai/code/session_01LetMoQcfT11iPmCMitx3oZ
