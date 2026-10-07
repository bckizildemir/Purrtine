# Handoff — CatCareCalendar architecture review

**From:** an unattended scheduled run on 2026-07-31, against `main` @ `5c6527e`.
**For:** whichever agent or person picks up one of the tickets below.
**The review itself:** [`architecture-review.md`](./architecture-review.md).
**Status, re-checked 2026-09-08:** issues **#12–#15 are closed**; **#16–#21 are still open**. Bulk
task edit is not a feature and its code is deleted (`docs/adr/0001-no-bulk-task-edit.md`), so #12's
subject and every `BulkTaskEditView` mention below is a July record — #16's live case is the
cat-rename leak. The
frontier table below is a July snapshot and is now wrong about #12–#15. Verify an issue against the
current code before you dispatch it — a closed ticket can still be open in the tracker and the
reverse also happens. The review's dependency line ("no third-party dependencies") was false; the
app links the `firebase-ios-sdk` package. See `docs/agents/doc-audit-2026-09.md`.

## What happened

Steps 1–2 of `/improve-codebase-architecture` were run: explore, then present candidates as a report.
**Step 3 (the grilling loop) was deliberately skipped** — nobody was at the keyboard, so no interface
has been designed for any candidate.

Nothing in the repo was modified during the review, and **no build, test or simulator run was
performed**. Every claim in the report is static evidence, not observed behaviour. Verify before
acting on it, and correct the report if something turns out to be wrong.

Five `Explore` sub-agents walked the hot spots identified from the last 60 commits' churn: the Task
Assistant cluster, the task create/edit surfaces, scheduling/recurrence/notifications, the
presentation struct family, and the launch/bootstrap chain. Their dossiers are not preserved — their
conclusions are in the report, and any claim you need to re-verify is one `grep` away using the
`path:line` citations it carries.

## Where things live

| | |
| --- | --- |
| **GitHub issues #12–#21** | **The source of truth for the work.** Native blocking edges; each issue links to its candidate in the report. Query with `gh issue list --state open`. |
| [`docs/architecture-review.md`](./architecture-review.md) | The report. Seven candidates, before/after diagrams, `path:line` evidence, top recommendation. |
| `.scratch/architecture-review/` | Local working notes from the original session — the HTML form of the report, the ticket drafts, the publishing record. **Gitignored**, so it exists only on the machine that ran the review. Nothing there is needed to do the work; the HTML is kept only because its hand-built diagrams (cross-sections, mass diagrams, depth bars) are richer than the tables they became in Markdown. |

## Issue map

| Issue | Label | Blocked by |
| --- | --- | --- |
| [#12](https://github.com/bckizildemir/CatCareCalendar/issues/12) Bulk task edit reconciles reminders | `ready-for-agent` | — |
| [#13](https://github.com/bckizildemir/CatCareCalendar/issues/13) Renaming a cat refreshes its reminder text | `ready-for-agent` | — |
| [#14](https://github.com/bckizildemir/CatCareCalendar/issues/14) Reassigning a caregiver actually saves | `ready-for-agent` | — |
| [#15](https://github.com/bckizildemir/CatCareCalendar/issues/15) Delete the dead code the architecture review surfaced | `ready-for-agent` | — |
| [#16](https://github.com/bckizildemir/CatCareCalendar/issues/16) Deepen: the care-task mutation seam | `ready-for-human` | #12, #13 |
| [#17](https://github.com/bckizildemir/CatCareCalendar/issues/17) Deepen: the recurrence rule as a module | `ready-for-human` | — |
| [#18](https://github.com/bckizildemir/CatCareCalendar/issues/18) Deepen: the task form draft | `ready-for-human` | #14, #15 |
| [#19](https://github.com/bckizildemir/CatCareCalendar/issues/19) Deepen: one understood intent for the Task Assistant | `ready-for-human` | — |
| [#20](https://github.com/bckizildemir/CatCareCalendar/issues/20) Deepen: inline the shallow presentation modules, consolidate the date predicates | `ready-for-human` | #17 |
| [#21](https://github.com/bckizildemir/CatCareCalendar/issues/21) Deepen: the launch sequence as one interface | `ready-for-human` | — |

At the time of writing the frontier — issues with no open blockers — was **#12, #13, #14, #15, #17,
#19, #21**, of which #12–#15 are agent-ready. **This table goes stale; the tracker does not.** For the
live frontier, list open issues and drop any whose `issue_dependencies_summary.blocked_by` is above
zero.

## The seven candidates, one line each

1. **The care-task mutation seam** — `Strong`. Reminder resync is a caller obligation, not a postcondition. The 15-field DTO build is duplicated 8×; `BulkTaskEditView` and cat rename never resync at all.
2. **The recurrence rule as a module** — `Strong`. The occurrence engine is deep and calendar-injected, but three ambient-`Calendar.current` layers sit above it; one rule is verified from four incompatible test setups.
3. **The task form draft** — `Strong`. `TaskFormDraft` covers 20 of `TaskAddView`'s 39 `@State` properties; 23 declarations are duplicated line-for-line into `TaskEditView`; neither save path has a test.
4. **One understood intent for the Task Assistant** — `Worth exploring`. Complete/postpone/open re-encoded in four enums across 19 switches.
5. **The presentation family: two deep, three shallow** — `Worth exploring`. `HistoryPresentation` and `NotificationSettingsPresentation` hide zero implementation; date predicates are duplicated across views.
6. **The launch sequence as one interface** — `Worth exploring`. Eleven collaborators in `CatCareCalendarApp.init`, ordering enforced only by comments.
7. **One-shot navigation as a value** — `Speculative`. **Not ticketed.** `CLAUDE.md` blesses the current pattern and it has produced one recorded bug. Revisit only if a seventh router flag is about to be added.

## What the next agent most needs to know

- **#16 is the top recommendation**, and candidate 1 is the only one where missing depth is already
  shipping wrong behaviour. **#12 and #13 are its shippable slices** and need no design work — take one
  of those for a clean first session.
- **#16–#21 are deepenings, not implementations.** A chosen deepening *generates an idea* that belongs
  in a design conversation first. Do not open one of those and start editing Swift; the interface has
  not been designed. #12–#15 are the only ones that are ready to build.
- **`docs/adr/` does not exist.** No ADRs constrain any of this. If a candidate is rejected for a
  load-bearing reason, that is the moment to create the directory and record it, so a future
  architecture review does not re-suggest the same thing.
- **`CONTEXT.md` is thin** — three terms: *Quick Action*, *Assistant Suggestion*, *Task Assistant*. The
  report deliberately did **not** invent names for the unnamed concepts it found. Two are worth naming
  during design: the recurrence rule (candidate 2) and the in-flight task form state (candidate 3). Add
  them to `CONTEXT.md` when they get named.
- **`CLAUDE.md` is binding and no candidate contradicts it.** Candidate 1 in particular *strengthens*
  the "all scheduling goes through `NotificationManager`" rule rather than replacing it — what moves
  behind an interface is the obligation to call it, not the scheduling itself.

## Verification constraints

These are in `CLAUDE.md` but they bite hard enough to repeat.

- Simulator baseline is **iPhone 12 / iOS 18.5** and **iPhone 12 / iOS 26.5**, run **sequentially**.
  Never boot both — this is a 16GB machine.
- Prefer the `xcodebuildmcp` MCP server over raw `xcodebuild`. Call `session_show_defaults` before the
  first build. Do **not** use the `mcp__Claude_Code_iOS_Simulator__*` tools in this repo.
- Swift Testing (`@Suite`/`@Test`/`#expect`) for unit tests; XCTest only for `CatCareCalendarUITests`.
- Use `TestModelContainerFactory`, `FakeUserNotificationCenterClient` and `NotificationSchedulerSpy`
  from `CatCareCalendarTests/TestSupport/` rather than real persistence or notification state.
- New user-facing strings go in `Resources/Localizable.xcstrings` with **both** `en` and `tr`
  translated, then `LocalizationParityTests` must pass.

## Suggested skills

Several skills the ideal flow would use are **not enabled in this workspace** — they exist in the
`mattpocock-skills` plugin cache but are not exposed, so invoking them by name will fail. Enabling the
full set is a plugin-settings change made from an interactive session.

| Skill | When | Enabled |
| --- | --- | --- |
| `/codebase-design` | The deep-module vocabulary the report is written in — module, interface, depth, seam, adapter, leverage, locality. Read it before arguing about a candidate. | Yes |
| `/tdd` | #12–#15 are behaviour changes with clear red tests available. Drive them test-first. | Yes |
| `/domain-modeling` | When candidate 2 or 3 gets a name, to keep `CONTEXT.md` honest. | Yes |
| `/code-review` | Two-axis review (Standards + Spec) of the diff before committing. | Yes |
| `/diagnosing-bugs` | If #12 or #13 reproduces differently than the static evidence predicts. | Yes |
| `/grill-with-docs` | Would be the first step for #16–#21: sharpens a deepening into a decided design with a `CONTEXT.md` / ADR paper trail. | **No** |
| `/to-spec` | Would collapse a grilled deepening into a buildable plan. | **No** |
| `/implement` | Would drive the per-ticket build loop. | **No** |

Start each ticket in a **fresh context window**. Do not carry this handoff plus a full design
conversation plus an implementation in one session.
