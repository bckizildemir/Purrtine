---
status: accepted
date: 2026-09-28
---

# The recurrence rule stays on the V1 stored fields

The recurrence rule ([#17](https://github.com/bckizildemir/CatCareCalendar/issues/17)) round-trips
between the stored `CareTaskSchedule` fields and the form's `RepeatConfiguration` without a new
schema version. The old mapping was lossy for three frequencies. Two of them are recovered from
fields V1 already stores; the third is made lossless by definition instead of by a new stored case.

- **Once** is read from `frequency == .once`. The rule models it directly, so the Add and Edit views
  lose their special case for it.
- **Biweekly** and **weekly with an interval of 2** are the same rule. The rule reads both and writes
  one canonical form, weekly with interval 2 — the form `RepeatConfiguration` already writes today.
  Existing `.biweekly` rows keep working unchanged.
- **Yearly** is defined as monthly with an interval that is a multiple of 12. A user who chose
  "every 12 months" sees "every year" after a round trip. Both produce the same dates.

## Considered options

- **Add a stored yearly case in `CatCareSchemaV2`.** A true lossless round trip, but it adds a
  migration stage and its tests to a refactor whose goal is module shape. Rejected for now.
- **Keep the lossy mapping and only move the code.** Leaves the view-side workaround for "once" in
  place. Rejected.

## Consequences

- "Every 12 months" and "every year" cannot be told apart. If the product ever needs them to differ,
  that is a new schema version, not an edit to V1 — supersede this ADR then.
- The rule's initializer owns the weekday invariant (0 = Sunday … 6 = Saturday, independent of the
  calendar's `firstWeekday`): it filters out-of-range values, removes duplicates, and treats weekly
  with no days as plain weekly. The four other checks are deleted.
