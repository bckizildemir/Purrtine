# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Last updated

2026-11-12

Last session:
- Merged: #99 (CI prints which UI tests passed only on retry; #97 closed), #133 (verify-purrtine: axe is the
  only driver), #139 (user-flow statecharts in `docs/flows/`), and three formal checks: #134 (onboarding
  finish), #136 (completing a repeating task), #138 (reminder resync).
- The formal checks found bugs, now issues: #140 (a kill after Start makes a second first cat), #141
  (completing a repeating task: 4 wrong-day paths), #142 (reminder snoozes: land after completion, outlive
  deletes, ignore Reminders off, no cap).
- #137 (AI notice on every AI result, for #135): on the simulator, rule-based answers correctly show no
  notice (run `2026-11-12-150536-6c78`). The cloud path is blocked: App Check and sign-in pass, then HTTP
  401, so the `GROQ_API_KEY` secret is invalid. Its UI test `testCatCardContextMenuAddTaskOpensFormWithCatPreselected`
  failed twice on CI; the PR does not touch cat cards.

## Open PRs

| PR | What it does | Waits for |
|---|---|---|
| #137 | Show an "AI can make mistakes" notice on every AI result (#135) | Green UI tests (cat card → Add Task test failed twice); the owner fixes `GROQ_API_KEY`, then a cloud proof (2 calls) |

## Next step

1. Get #137 green: find why the cat-card Add Task UI test fails on its branch.
2. Fix #140, #141 and #142 (the formal-check bugs).
3. Stage 2 polish: #124 (Polish 1: shared motion tokens) first, since #125 (Home cards without glass)
   and #127 (onboarding fades) depend on it. #126, #128, #129 and #130 name no such dependency.
   The plan is in `docs/stage2-polish-decisions.md`.
4. Still `ready-for-agent`: #9 (feeding details saved, schema V2).

## Waits for the owner

- Fix the `GROQ_API_KEY` secret (Whiskers cloud calls get HTTP 401).
- #12 (App Store readiness): the Groq retention window and the App Store ID.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
