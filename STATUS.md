# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Focus

Stage 2 polish (animation and look), plan `docs/stage2-polish-decisions.md` (the animation audit and decisions,
#131, are done). Done 1/7. Items (#125 and #127 depended on #124, now merged):
- #124 (Polish 1: shared motion tokens): done, #158 merged 2026-11-16
- #125 (Polish 2: Home cards and task rows lose glass)
- #126 (Polish 3: Apple calendar view)
- #127 (Polish 4: onboarding fades)
- #128 (Polish 5: line-art Whiskers cat in empty states)
- #129 (Polish 6: Whiskers chat motion)
- #130 (Polish 7: Reduce Motion, haptics, curves)

## Last updated

2026-11-16

Last session:
- 2026-11-16 (latest): #156 (repeating-task day fix, closes #141) merged (squash, owner's yes) as `77ef65b`.
  Owner decision 2 = allow any day up to today with no completion; future and already-done days are refused;
  a fill-in of an earlier day only records that day. Review fixes: on-time judged on the recorded day, History,
  Home routine status and Settings weekly count use the performed day (`CareTaskCompletion.performedAt`).
  Simulator proofs PASS (runs `2026-11-16-121258-4944`, `2026-11-16-125755-713c`); CI green incl. UI tests.
  `interpretTaskAssistantRequest` deployed after the merge (owner's yes): revision `00006-dol`, ready. It adds
  the cloud interpreter's `"today"` day.
- 2026-11-16 (later): #158 (Polish 1: shared motion tokens, closes #124) reviewed with `/code-review`, branch
  updated, CI green incl. UI tests, merged (squash, owner's yes). Review notes left for #130 (Polish 7: Reduce
  Motion): `Motion.resolve(_:reduceMotion:)` only swaps the curve for a 0.15 s ease-out, it does not remove
  movement, although its doc comment says "short fade"; callers must also swap scale/offset transitions; the plan
  in `docs/animation-audit.md` returns `Animation?`, the code a non-optional. `MotionTests` check only that
  tokens differ, not their values.
  #156 (repeating-task day fix): owner decision 1 = (a): a refused reminder Complete now posts a "Not recorded"
  notice (`completion_refused_<taskId>`, en + tr, skipped when Reminders are off), commit `0611c8d`, 4 new unit
  tests, suites green locally; CI pending. Decision 2 still open (see "Waits for the owner").
  New open PR #159 (fix #152: make the CI UI tests reliable): `UI tests` red, still in work.
- 2026-11-16 (checked on GitHub that day): #154 merged 2026-11-15 (a kill after onboarding Start no longer
  makes a second first cat) and #140 is closed. Three PRs stay open:
  - #155 (reminder snooze fixes, for #142): branch updated from main 2026-11-15, unit tests green, `UI tests` red
    on `testSimulatedNotificationSnoozeKeepsTaskPendingAndShowsPendingNotification`, a snooze test, so likely
    tied to the change, not to #152. Another agent is working on it.
  - #156 (repeating-task day fix, for #141): CI green (run of 2026-11-14), not updated since. Waits for two owner
    decisions (see "Waits for the owner"), and has no verify-purrtine proof yet. #155 and #156 conflict in
    `NotificationActionCoordinator.swift` and its tests; whichever merges second fixes that.
  - #149 (build number 14): branch updated 2026-11-15, unit tests green, `UI tests` red again (both attempts;
    this time `testCatCardContextMenuAddTaskOpensFormWithCatPreselected`), a different test each run, which
    looks like the flakiness in #152. So main still says build 13, while build 14 is already with the
    external testers.
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

1. Stage 2 polish (the Focus): #124 is done (#158), so #125 (Home cards without glass) and #127 (onboarding
   fades) can start; #126, #128, #129 and #130 can start any time. The plan is in `docs/stage2-polish-decisions.md`.
2. Land the formal-check fixes: #140 is done (#154), #141 is done (#156); #142 is in #155 (rebase it on main:
   #156 touched `NotificationActionCoordinator.swift` and its tests). Merge #149 (build 14) once the UI tests pass or #152 (flaky UI tests) is fixed.
3. Postponed by the owner 2026-11-16 (a later task, no issue yet): after #156, a missed earlier day of a repeating
   task can be filled in from a reminder or Whiskers, but the calendar shows that day as "No tasks". Show a missed
   day in the calendar as missed and let the user complete it there. Waits because the owner said "yes, but as a later
   task"; start trigger: the owner picks it. First step: open an issue.
4. #9 (feeding details are saved, schema V3: V2 is already on main, so it adds V3 with a V2→V3 step) is
   blocked by #2 (Deepen: the task form draft; open, `ready-for-human`, no PR), so it lost `ready-for-agent`.
   It becomes ready when #2 merges.

## Waits for the owner

- #12 (App Store readiness): the Groq retention window and the App Store ID.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
