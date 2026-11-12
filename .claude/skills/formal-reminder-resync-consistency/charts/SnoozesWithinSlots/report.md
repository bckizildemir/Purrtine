# ReminderResync

TLC reached more states than the chart budget of 500, so the chart draws only the bug paths: 7 states and 6 arrows.
With VIEW, TLC keeps one representative for each group of states that it counts as the same. An arrow can lead to the representative rather than to the state that the step reaches.

## SnoozesWithinSlots breaks
The shortest path has 6 steps:
0. Settled, permission not read yet, no snooze
1. you tap Remind me on a reminder: snooze tapped, permission not read yet, no snooze
2. the snooze looks up the task: resync running + snooze on its way, reminders on, no snooze
3. the snooze is scheduled: resync running, reminders on, 1 snooze
4. you tap Remind me on a reminder: resync running + snooze tapped, reminders on, 1 snooze
5. the snooze looks up the task: resync running + snooze on its way, reminders on, 1 snooze
6. the snooze is scheduled: resync running, reminders on, 2 snoozes

## Rules not checked
NoDeadlock
After the first break, each TLC run stops at 100,000 distinct states. A run reached that bound before it checked this rule in every state.
