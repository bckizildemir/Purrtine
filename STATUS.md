# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Last updated

2026-11-11

Last session:
- The owner merged #118 (category icon on each Tasks row), #119 (Whiskers skips tasks done today) and
  #120 (this file); #116 and #117 closed. #123 (route Apple's Xcode 27 skills) merged too.
- New rule "Safe merges" in CLAUDE.md: agents merge green docs-only PRs and Dependabot patch/minor bumps
  themselves. Under it, #131 (stage 2 polish decisions, animation audit, ideas file) was updated to `main`
  and merged once its CI went green.
- A grilling round on stage 2 polish opened #124-#130 (Polish 1-7), all `ready-for-agent`.

## Open PRs

| PR | What it does | Waits for |
|---|---|---|
| #99 | CI: print UI-test retry results in the ui-tests job (#97) | Rebase on `main` to fix the `ci.yml` conflict, green CI, then the owner's merge; then close #97 |

## Next step

1. Fix the #99 conflict in a separate session (not the one that merges it), wait for CI, merge, close #97.
2. Stage 2 polish: #124 (Polish 1: shared motion tokens) first, since #125 (Home cards without glass)
   and #127 (onboarding fades) depend on it. #126 (Apple calendar view), #128 (line-art Whiskers cat),
   #129 (Whiskers chat motion) and #130 (Reduce Motion and haptics) name no such dependency in their issue text.
   The plan is in `docs/stage2-polish-decisions.md`.
3. Still `ready-for-agent`: #9 (feeding details saved, schema V2).

## Waits for the owner

- #12 (App Store readiness): the Groq retention window and the App Store ID.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
