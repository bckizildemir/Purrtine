# 2026-11-01 — Nudge never lands minutes away; a horizon stop is a cut (#93)

Three follow-ups from the re-review of the nudge (#11, `2026-10-28-reminder-nudge.md`).

## What changed

- `CareTaskReminderSelection.nudgeFireDate` floors the nudge at one hour after `now`
  (`minimumGap`). A full 59-reminder set inside the hour put the midpoint a minute out, so the
  caregiver got "open the app" while still using it. The floor applies to both the
  `nudgeLeadTime` path and the midpoint path, so a series whose last reminder is 24 hours and
  2 minutes away no longer nudges 2 minutes from now either.
- A series stopped by the 12-month scheduling horizon now counts as a cut. A task that repeats
  every three months fills 5 of its 6 slots inside the horizon, so its reminders would stop
  silently after about a year of the app staying closed. It gets a nudge like a series cut by its
  own cap. The horizon counts only when the pass produced more than one reminder: with a single
  one — an interval longer than the horizon — opening the app cannot schedule more either, and the
  nudge would fire before that lone reminder.
- Renames to match: `ReminderOccurrenceSeries.cutEnd`, `ReminderSelectionPass.cutSeriesEnds`, and
  `nudgeFireDate(cutSeriesEnds:)`; the old names said "cap" for what is now any short stop.
- Tests: a floor test for each path; a resync test for a daily series with an `endDate` 5 days out
  (6 reminders, no nudge); a resync test for a 3-monthly series stopped by the horizon (5 reminders
  and a nudge 24 hours before the last).
