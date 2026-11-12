# RecurringCompletion

TLC reached more states than the chart budget of 500, so the chart draws only the bug paths: 7 states and 8 arrows.

## NoOccurrenceSkipped breaks
The shortest path has 2 steps:
0. Due day 0, today is day 0 (nothing done yet)
1. a caregiver picks day 1 in the calendar and taps Complete: Due day 0, today is day 0 (nothing done yet)
2. the calendar's Complete saves a completion for day 1: Due day 2, today is day 0 (done: day 1)

## CompletesTheOccurrenceShown breaks
The shortest path has 3 steps:
0. Due day 0, today is day 0 (nothing done yet)
1. a new day begins: Due day 0, today is day 1 (nothing done yet)
2. the reminder for day 1 arrives: Due day 0, today is day 1 (nothing done yet)
3. Complete on the reminder saves a completion for day 0: Due day 1, today is day 1 (done: day 0)

## CompletedNeverReappears breaks
The shortest path has 4 steps:
0. Due day 0, today is day 0 (nothing done yet)
1. the reminder for day 0 arrives: Due day 0, today is day 0 (nothing done yet)
2. a caregiver opens Edit Task (date shows day 0): Due day 0, today is day 0 (nothing done yet)
3. Complete on the reminder saves a completion for day 0: Due day 1, today is day 0 (done: day 0)
4. the caregiver saves Edit Task: Due day 0, today is day 0 (done: day 0)

## NeverCompletedTwice breaks
The shortest path has 4 steps:
0. Due day 0, today is day 0 (nothing done yet)
1. a caregiver taps Complete in the task list for day 0: Due day 0, today is day 0 (nothing done yet)
2. a caregiver tells Whiskers it was done on day 0; Whiskers asks to confirm: Due day 0, today is day 0 (nothing done yet)
3. the task list's Complete (row or sheet) saves a completion for day 0: Due day 1, today is day 0 (done: day 0)
4. Whiskers' confirmation saves a completion for day 0: Due day 1, today is day 0 (done: day 0, day 0)

## Rules not checked
TypeOK, OneActiveScheduleOrClosed, NextIsStrictlyLater, FailedSaveChangesNothing, NoDeadlock
After the first break, each TLC run stops at 100,000 distinct states. A run reached that bound before it checked these rules in every state.
