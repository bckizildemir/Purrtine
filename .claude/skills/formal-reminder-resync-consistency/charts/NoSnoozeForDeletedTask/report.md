# ReminderResync

TLC reached more states than the chart budget of 500, so the chart draws only the bug paths: 8 states and 8 arrows.
With VIEW, TLC keeps one representative for each group of states that it counts as the same. An arrow can lead to the representative rather than to the state that the step reaches.

## NoSnoozeForDeletedTask breaks
The shortest path has 11 steps:
0. Settled, permission not read yet, no snooze
1. you switch reminders in Settings: resync running, permission not read yet, no snooze
2. the app launches and reads the permission: resync running, reminders off, no snooze
3. you tap Remind me on a reminder: resync running + snooze tapped, reminders off, no snooze
4. the snooze looks up the task: resync running + snooze on its way, reminders off, no snooze
5. you delete the cat: resync running + snooze on its way for a finished task, reminders off, no snooze
6. the resync reads the saved tasks: resync running + snooze on its way for a finished task, reminders off, no snooze
7. the resync reads the permission: resync running + snooze on its way for a finished task, reminders off, no snooze
8. the resync reads the pending reminders: resync running + snooze on its way for a finished task, reminders off, no snooze
9. the resync removes stale reminders: resync running + snooze on its way for a finished task, reminders off, no snooze
10. the resync finishes: snooze on its way for a finished task, reminders off, no snooze
11. the snooze is scheduled: Settled, reminders off, a snooze for a finished or deleted task

## Rules not checked
NoDeadlock
After the first break, each TLC run stops at 100,000 distinct states. A run reached that bound before it checked this rule in every state.
