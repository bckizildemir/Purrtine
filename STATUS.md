# STATUS

Hand-off file: where the work stands. Read it at session start; update it before the final report.

## Focus

Robustness first (owner, 2026-11-17): a red CI blocks every merge, and bugs damage user data while polish can wait.
Items, in this order:
- #152 (CI UI tests are flaky): done, #159 merged 2026-11-17
- #142 (reminder snoozes outlive completion and deletes, ignore Reminders off): done, #155 merged 2026-11-18;
  two narrow gaps left in #173 (failed cat delete keeps snoozes; "Remind me" on a finished day)
- CI quick pack: done, #171 merged 2026-11-18 (TriQ #192 too)
- #149 (build number 14): merged; that build 14 (with #156, without #163) was never uploaded. Build 15 (#194,
  with #156 and #163 together) is uploaded and sent to the external testers through beta review, 2026-11-19.
- #163 (a completion records when the care was done and which day it counts for): done, #192 merged and
  `interpretTaskAssistantRequest` deployed 2026-11-18. Follow-ups in #193 (Turkish "akşam 9", VoiceOver double
  read, race message, calendar due label, TR "beslendi" unproved, 00:00 edge).
- Next: the recurrence chain #1, #164, #165 (see "Next step" 5), then #173 and #193.

Then Stage 2 polish (animation and look) resumes, plan `docs/stage2-polish-decisions.md` (the animation audit and
decisions, #131, are done). Done 1/7. Items (#125 and #127 depended on #124, now merged):
- #124 (Polish 1: shared motion tokens): done, #158 merged 2026-11-16
- #125 (Polish 2: Home cards and task rows lose glass)
- #126 (Polish 3: Apple calendar view)
- #127 (Polish 4: onboarding fades)
- #128 (Polish 5: line-art Whiskers cat in empty states)
- #129 (Polish 6: Whiskers chat motion)
- #130 (Polish 7: Reduce Motion, haptics, curves)

## Last updated

2026-11-19

Last session:
- 2026-11-19: #194 (build 15 + STATUS) and #190 (GitHub Actions majors: checkout, cache, setup-node,
  upload-artifact) merged, #190 after an update-branch and a green CI (UI tests 34 min). The owner accepted the
  App Store Connect agreement; API writes came back about 30 minutes after reads did. Build 15 uploaded (`VALID`,
  build id `fa438490-5764-4679-896a-642666623160`) and submitted to beta review for the External Testers group
  (`"betaReviewSubmitted":true`); external testers had build 14 from 2026-11-12 (Whiskers fix). #191
  (firebase-admin 13 → 14 in `functions`) waits for the owner's yes to merge and deploy; the deploy also ships #187.
- 2026-11-18 (later): #188 and TriQ #214/#218 merged: Dependabot version-updates only Firebase (and Nuke in TriQ)
  among Swift packages; majors come as one grouped PR, not ignored, so security updates are never blocked
  (owner: "güvenlikleri atlamayalım"). #187 deployed. #163 via `/implement`: `swift-writer` TDD, two reviews
  (standards, spec), a fix round, two `verify-purrtine` passes EN+TR (`~/verify-evidence/purrtine/2026-11-18-114806-2ba7`,
  `-114913-516b`), CI green 50/50 UI; merged as #192 and deployed. Build 14 held; build 15 archived. TestFlight
  upload is blocked: App Store Connect says an agreement is unsigned or expired (owner must accept at
  https://appstoreconnect.apple.com/agreements).
- 2026-11-18 (resumed; the owner said "merge when they're ready, UI test should be green"):
  - Docs PRs #172 and TriQ #193 merged. TriQ #192 (CI quick pack) merged.
  - #155 (#142 snoozes): a `swift-reviewer` pass found the main merge lost nothing. Its one low-medium finding was
    fixed on the PR (`b47503e`): the 4-slot cap checked that the new snooze still counts only after removing the
    oldest one. The new test waits on the `snoozeGenerations` bump (now `private(set)`), not on one `Task.yield()`
    (`e988dfe`). CI green, 50 UI tests with no retry warning; merged. The two other findings are #173.
  - One CI run was cancelled by GitHub ("job was not acquired by Runner", macOS capacity), not by a test; an
    update-branch reran it.
  - #171 (CI quick pack) updated from main, CI green with no retry warning; merged. The job "Detect UI-test paths"
    is now "Detect changed paths" (not a required check).
  - #149 (build 14) updated from main, CI green with no retry warning; merged.
  - Dependabot's first run (after #171) opened 12 PRs. Merged: #177 (firebase-functions 7.3.0 → 7.4.0, minor) and
    #187 (fast-xml-parser 5.10.1 → 5.12.1, a security update, lockfile only). The 11 major or Firebase-internal
    ones were closed on the owner's go. PR #188 makes Dependabot propose minor and patch only, and Swift only
    `firebase-ios-sdk`; it waits for the owner (CI config).
  - Deployed on the owner's yes: `interpretTaskAssistantRequest` (europe-west1) with #177. "Successful update
    operation"; revision `-00007-non` is both latest created and latest ready. No live call was made (it reaches
    the paid model API). #187 is merged but not deployed yet.
  - On the owner's yes: "UI tests" is now a required check in ruleset `main-ci`, and Dependabot security updates
    are on.
  - Next in Focus: #163 (a completion records which day it counts for).
- 2026-11-17 (paused by the owner mid-run; resume from here):
  - #159 merged (owner's go): a failed UI test now really retries (sync tearDown), safer taps and waits, the
    double-save tests send one `doubleTap()`, and a test that passes only on retry shows as a `::warning`
    annotation and in the job's step summary. Last two CI runs: 50/50 UI tests, no retry needed.
  - CI audit of both apps (read-only, last 60 runs). The owner approved a quick pack now and the rest later
    ("Next step" 7). Purrtine quick pack is PR #171 (branch `ci/ci-pack`, worktree `../wt-p-ci`): cancel in progress
    only on PRs; push to main runs the UI tests only when app paths changed; the `app` job skips docs-only changes
    (job names unchanged, a skipped job passes a required check); shared `Scripts/ci-pick-simulator.sh` (identical to
    TriQ's) in the `app` job; Xcode pinned to 26.6; actions pinned to SHAs; `.github/dependabot.yml`. Unit job green
    (8.5 min, was ~12.7). UI job run 44085128337 was still running. Not proven until the next docs-only merge: the
    skip on push. Dependabot security updates are disabled in the repo settings (needs the owner).
  - Tried in TriQ and dropped: booting the simulator during the build made the build 2-3x slower.
  - #155: main merged in, conflicts resolved, pushed; its UI job was still running.
  - To resume: `gh pr checks 171` and `gh pr checks 155`; if UI tests are red, read the failing test from the log
    before changing anything; then ask the owner to merge #171 and #155, then update and merge #149.
- 2026-11-17 (later): the owner reordered the focus: robustness (#152 flaky CI UI tests, #142 snoozes, #149
  build 14, #163) before the polish items. PR #159 CI run 43793613651: the retry now runs, but
  `testTaskEditDoubleSaveTapUpdatesTaskOnce` failed on both attempts ("No matches found for taskEdit.saveButton"
  after the first tap closed the sheet); a fix is in work on the PR.
- 2026-11-17: #169 merged (owner's go). `lastCompletionDisplayText(relativeTo:)` and `dueDisplayText(relativeTo:)`
  read the clock instead of their reference date, so the #156 test pinned to 2026-11-16 failed from 2026-11-17 and
  turned CI red; both now compare start-of-day values with the reference date. Same PR: the custom repeat summary
  reads "Repeats: %@" / "Tekrar: %@". Preview tooling steps A and B done (item 6).
- 2026-11-16 (night, lessons): `session-lessons` after the #1 grilling. Written: owner preferences that must hold in
  every folder go in `~/.claude/CLAUDE.md` or a skill, not project memory; keep a recommendation stable between
  rounds; `decision-check` shows the owner the real screens; `verify-purrtine` gotcha: an open sheet does not hide
  the screen behind it from `$V ui`. New global skill `show-in-yazi` and the `/in-your-own-words` skill.
- 2026-11-16 (night): grilling round on #1 (Deepen: the recurrence rule as a module) with the owner, then the
  Swift-skill check (`decision-check`). Root cause named: one pair of dates (`completedForDate`, `completedAt`) does two
  jobs, and "which day" is a loose `Date?` through ~30 spots. Four steps, in this order: #163 (fix: a completion records
  when the care was done and which day it counts for; `ready-for-agent`), then #1, then #164 (typed day and one
  target choice), then #165 (setting "count the next day from the day I did it", new schema version, after #2).
  New glossary words (Occurrence, Open Occurrence, Missed Occurrence, Fill-in), the idea #162 (linked care tasks) in
  `docs/IDEAS.md`, and the research in `docs/repeat-completion-research.md` (docs PR #166, squash-merged by the
  agent once CI was green). Decisions are in a comment on #1. Owner
  answers still to come: none open. The Whiskers time field needs a cloud deploy, which needs the owner's separate yes.
- 2026-11-16 (earlier): #156 (repeating-task day fix, closes #141) merged (squash, owner's yes) as `77ef65b`.
  Owner decision 2 = allow any day up to today with no completion; future and already-done days are refused;
  a fill-in of an earlier day only records that day. Review fixes: on-time judged on the recorded day, History,
  Home routine status and Settings weekly count used a "performed" day (`performedAt`; #163 replaced it: every
  "when" read is `CareTaskCompletion.completedAt`, and `isFillIn()` is `completedAt == completedForDate`).
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

1. Stage 2 polish (after the robustness items in Focus): #124 is done (#158), so #125 (Home cards without glass) and #127 (onboarding
   fades) can start; #126, #128, #129 and #130 can start any time. The plan is in `docs/stage2-polish-decisions.md`.
2. The formal-check fixes are landed: #140 (#154), #141 (#156), #142 (#155). Follow-up: #173 (two narrow snooze
   gaps from the #155 review). Build 15 (with #156 and #163) is in beta review for external testers (2026-11-19).
3. Postponed by the owner 2026-11-16 (a later task, no issue yet): after #156, a missed earlier day of a repeating
   task can be filled in from a reminder or Whiskers, but the calendar shows that day as "No tasks". Show a missed
   day in the calendar as missed and let the user complete it there. Waits because the owner said "yes, but as a later
   task"; start trigger: the owner picks it. First step: open an issue.
4. #9 (feeding details are saved, schema V3: V2 is already on main, so it adds V3 with a V2→V3 step) is
   blocked by #2 (Deepen: the task form draft; open, `ready-for-human`, no PR), so it lost `ready-for-agent`.
   It becomes ready when #2 merges. #165 (the "count from the day I did it" setting) also needs a schema version
   and takes the next free one; whichever merges second takes the version after it.
5. Recurrence chain, decided 2026-11-16: #163 (fix) first, then #1, then #164, then #165 (see "Last session").
6. SwiftUI Preview rendering through Xcode's MCP server (`xcode`, `xcrun mcpbridge`, tool `RenderPreview`), both
   apps. Step A is done (2026-11-17): the global `preview` skill (`~/.claude/skills/preview/`) renders a `#Preview` to
   `~/preview-renders/<app>/` and shows it with `show-in-yazi`; `decision-check` step 4 now uses it for screens a
   decision changes. Proved on `CustomRepeatSheet.swift` in Turkish dark and English light. It must name the render
   device: left to Xcode it drew on the work project's `iPhone 12 slim (CWA)`. Step B is done (2026-11-17): the
   `swiftui-preview` mod (`~/.claude/mods/swiftui-preview/`, loaded in every session through
   `CLAUDE_CODE_PLUGIN_DIRS` in `~/.claude/settings.json`) keeps each render's PNG, draws it in a "SwiftUI Preview"
   pane (`/preview-pane` reopens it), and refuses a render that names no device. A preview shows layout with sample
   data only; behavior still needs `verify-purrtine`. Postponed by the owner 2026-11-17 ("will do later"; Yazi is
   enough for now): an interactive preview, and centering the image in Yazi. `docs/swiftui-preview-interaction-research.md`
   holds what is possible (no mod can drive a `#Preview` today; nearest: an "open in Xcode" button, or a pisim-style
   simulator stream in a herdr pane; Yazi centering only by padding the PNG). Start trigger: the owner picks one.
7. CI improvements from the 2026-11-17 audit (both apps). The quick pack is merged (#171, TriQ #192, 2026-11-18).
   The bigger items wait; start trigger: the owner picks one:
   - Split the 50 UI tests (one class, ~26 min serial) into 3-4 parallel jobs: ~35 min → ~12-15 min. Free on a
     public repo; the free plan runs about 5 macOS jobs at once, so a TriQ run may queue.
   - A test summary on the PR page (failed tests, slowest tests, coverage per target) from `xcresulttool`, plus
     `::error` annotations for failed tests; artifact `retention-days`.
   - Raise the coverage floor (`MINIMUM_LINE_COVERAGE` 17.5, actual 24.48%) to ~24 and ratchet it.
   - Move `npm audit` out of the required job (weekly schedule or warning only): a new advisory would block every PR.
   - Try a DerivedData cache (measure first).
   - Done 2026-11-18: "UI tests" is a required check; Dependabot security updates are on.
   - Major dependency upgrades: Firebase iOS SDK 11 → 13 (a planned task). The GitHub actions on Node 20 are done
     (#190, 2026-11-19). firebase-admin 13 → 14 in `functions` is PR #191, waiting for the owner.

## Waits for the owner

- #191 (firebase-admin 13 → 14): a yes to merge, then a yes to deploy `interpretTaskAssistantRequest`
  (europe-west1), which also ships #187 (fast-xml-parser security fix, merged but not deployed).

- #12 (App Store readiness): the Groq retention window and the App Store ID.
- Issues marked `ready-for-human`: #1-#5 (deepen modules), #36 (camera photo memory, sRGB vs Display P3).
