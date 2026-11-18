# 2026-11-18 — A completion records when the care was done and which day it counts for (#163)

One pair of dates did two jobs: `completedForDate` meant "which occurrence I answer" and, through
`isFillIn` / `performedAt` (#156), also "when the care was done". A plain late tap (due Monday, tapped
Wednesday) was stored as a fill-in: History showed Monday with no time, and the Settings weekly count
could drop it.

## What changed

- `completedAt` is always when the care was done. `completedForDate` is the day the completion counts
  for. A fill-in is `completedAt == completedForDate` (both the start of that day); `isFillIn()` compares
  the two stored values. `performedAt` is gone: History, `lastCompletion`, Home recency, the weekly count
  and the debug filter read `completedAt`.
- A plain tap records the real time and counts for the open day. A named past day on a timed task stores
  that task's time; on a timeless task it is a fill-in. A stated time ("yesterday at 9") is stored and is
  not a fill-in. A named day is accepted from the task's first day (the earlier of its creation day and
  its open day) up to today while it has no completion; a day after today, a day already done, a day
  before the first day and a stated time after now are refused.
- The calendar no longer offers Complete (checkmark or swipe) on a refused day. The row says why
  (`task.calendar.refusal_*`); the alert stays only for a race, and then names the same reason.
- Whiskers answers a refused day or time with the reason in the chat instead of a confirm card.
- Whiskers reads a stated time: the cloud function returns `completedAtTime` as wall-clock `HH:mm`, and the
  local interpreter reads "at 9", "saat 9", "9:30", "9 pm" (a bare dotted number such as "0.25 ml" is not
  a time). A time that does not exist that day (a spring-forward gap) resolves to the next valid time.
- New copy: `task.calendar.refusal_time_not_yet` ("That time hasn't come yet", en + tr).

## Accepted edges

- A timed task at 00:00, or a stated "at 00:00", reads as a fill-in and shows no time.
- No migration: TestFlight build 14 predates #156, so every stored row reads as "not a fill-in".
- With "count from the day I did it" off, a late tap on a fixed every-2-days task lands on today again.

## Tests

`CareTaskCompletionPerformedAtTests`, `TaskActionServiceTests`, `HistoryPresentationTests` (row date and
time), `HomeRoutineStatusPresentationTests`, `TaskAssistantInterpreterTests`, `TaskAssistantViewModelTests`,
`TaskManagementViewModelTests`, `TimeOfDayTests`, `LocalizationParityTests`, and
`functions/taskInterpreterProxy.test.js`.
