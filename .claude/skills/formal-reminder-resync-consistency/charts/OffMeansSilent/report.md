# ReminderResync

TLC reached more states than the chart budget of 500, so the chart draws only the bug paths: 7 states and 9 arrows.
With VIEW, TLC keeps one representative for each group of states that it counts as the same. An arrow can lead to the representative rather than to the state that the step reaches.

## OffMeansSilent breaks
The shortest path has 10 steps:
0. Settled, permission not read yet, no snooze
1. you switch reminders in Settings: resync running, permission not read yet, no snooze
2. the resync reads the saved tasks: resync running, permission not read yet, no snooze
3. the resync reads the permission: resync running, reminders off, no snooze
4. the resync reads the pending reminders: resync running, reminders off, no snooze
5. the resync removes stale reminders: resync running, reminders off, no snooze
6. the resync finishes: Settled, reminders off, no snooze
7. the app launches and reads the permission: Settled, reminders off, no snooze
8. you tap Remind me on a reminder: snooze tapped, reminders off, no snooze
9. the snooze looks up the task: snooze on its way, reminders off, no snooze
10. the snooze is scheduled: Settled, reminders off, 1 snooze

## Rules not checked
NoDeadlock
After the first break, each TLC run stops at 100,000 distinct states. A run reached that bound before it checked this rule in every state.
