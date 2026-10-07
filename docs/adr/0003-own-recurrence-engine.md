---
status: accepted
date: 2026-09-28
---

# Keep the app's own recurrence engine instead of Foundation's `Calendar.RecurrenceRule`

Foundation ships `Calendar.RecurrenceRule` from iOS 18, inside this app's deployment target (18.4).
The recurrence rule module ([#17](https://github.com/bckizildemir/CatCareCalendar/issues/17)) still
wraps the app's own engine (today in `Models/CareTask.swift`). That engine carries tested fixes for
time zones where a day or a week has no local midnight or a wall time does not exist (America/Nuuk,
America/Scoresbysund, Australia/Lord_Howe, Asia/Beirut and others). Nobody has measured Foundation's
type against those cases, and a wrong answer here stops a task's reminders silently.

The Swift type is named `CareRecurrenceRule`, not `RecurrenceRule`, so that code search and readers do
not confuse it with `Calendar.RecurrenceRule`. The domain term in `CONTEXT.md` stays
"Recurrence Rule".

## Consequences

- The engine's DST and no-midnight tests stay the contract. A later move to Foundation's type is
  allowed only behind the same interface and only when those tests pass unchanged on it.
- The rule is a value built from a `CareTaskSchedule` and a `Calendar`. Callers inject the calendar
  once (`init`, default `.current`) instead of reading `Calendar.current` at each use.
