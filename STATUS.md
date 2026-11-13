# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Focus

Stage 2 polish (animation and look), plan `docs/stage2-polish-decisions.md` (the animation audit and decisions,
#131, are done). Items, #124 first (#125 and #127 depend on it):
- #124 (Polish 1: shared motion tokens)
- #125 (Polish 2: Home cards and task rows lose glass)
- #126 (Polish 3: Apple calendar view)
- #127 (Polish 4: onboarding fades)
- #128 (Polish 5: line-art Whiskers cat in empty states)
- #129 (Polish 6: Whiskers chat motion)
- #130 (Polish 7: Reduce Motion, haptics, curves)

## Last updated

2026-11-13

Last session:
- 2026-11-13 (later): build number 14 (#149). The `## Open PRs` section left this file: GitHub is the only
  list of open PRs (`gh pr list`, or `/where`), so the file cannot go stale on it. TestFlight: build 14 is uploaded,
  `VALID`, and sent to the External Testers group and Apple's beta review (waits for Apple). The release skill
  moved to `~/.claude/skills/testflight-release` (both apps, #151). #152 opened (CI UI tests are flaky: 3 of 4
  runs on #149 failed, each on a different test).
- 2026-11-13: `CLAUDE.md` trimmed from 270 to 148 lines (docs only). Coding conventions, notifications,
  SwiftData and localization rules moved to path rules in `.claude/rules/`; the Swift skill routing table and the
  version reconciliation now live only in `.claude/rules/swift-skills.md`. `CLAUDE.md` has a "Path rules" table
  that names each file, for agents that do not load `.claude/rules/` (Codex).
- Late 2026-11-12: #144 merged and `interpretTaskAssistantRequest` deployed (revision 00005, `openai/gpt-oss-120b`);
  #137 proved on the simulator (run `2026-11-12-205439-4e30`: a cloud confirmation card shows "AI-generated. AI can
  make mistakes; check important info.") and merged; #135 closed. Not proved: the notice on the "Which one did you
  mean?" card, and Turkish.
- Later on 2026-11-12: new Groq key set and the Whiskers function redeployed; calls then got HTTP 400 from the
  retired model, fixed in #144. verify-purrtine maintenance pass merged (#145, run `2026-11-12-181821-0f93`).
  Formal checks re-run: all in sync, still failing on #140-#142.
- Merged: #99 (CI prints which UI tests passed only on retry; #97 closed), #133 (verify-purrtine: axe is the
  only driver), #139 (user-flow statecharts in `docs/flows/`), and three formal checks: #134 (onboarding
  finish), #136 (completing a repeating task), #138 (reminder resync).
- The formal checks found bugs, now issues: #140 (a kill after Start makes a second first cat), #141
  (completing a repeating task: 4 wrong-day paths), #142 (reminder snoozes: land after completion, outlive
  deletes, ignore Reminders off, no cap).

## Next step

1. Stage 2 polish (the Focus): #124 (Polish 1: shared motion tokens) first, since #125 (Home cards without glass)
   and #127 (onboarding fades) depend on it. #126, #128, #129 and #130 name no such dependency.
   The plan is in `docs/stage2-polish-decisions.md`.
2. Fix #140, #141 and #142 (the formal-check bugs).
3. Still `ready-for-agent`: #9 (feeding details saved, schema V2).

## Waits for the owner

- #12 (App Store readiness): the Groq retention window and the App Store ID.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
