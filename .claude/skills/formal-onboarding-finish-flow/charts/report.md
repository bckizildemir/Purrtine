# OnboardingFinish

TLC reached 198 states and 989 steps. The chart draws 13 states and 27 arrows.
The chart does not draw 442 steps that stay in one chart state.
The view hides 222 steps, so the chart does not draw them.
With VIEW, TLC keeps one representative for each group of states that it counts as the same. An arrow can lead to the representative rather than to the state that the step reaches.

## NoSavedCatBehindOnboarding breaks
The shortest path has 7 steps:
0. Welcome
1. you tap Continue: Notifications
2. you allow notifications: Your first cat
3. you name the cat and tap Continue: Starter tasks
4. you tick a starter task: Starter tasks
5. you tap Start: Saving your first cat
6. the cat and tasks are written: Saving your first cat
7. the app is killed and opened again: Welcome, a cat already saved

## OneFirstCat breaks
The shortest path has 12 steps:
0. Welcome
1. you tap Continue: Notifications
2. you allow notifications: Your first cat
3. you name the cat and tap Continue: Starter tasks
4. you tick a starter task: Starter tasks
5. you tap Start: Saving your first cat
6. the cat and tasks are written: Saving your first cat
7. the app is killed and opened again: Welcome, a cat already saved
8. you tap Continue: Notifications, a cat already saved
9. you allow notifications: Your first cat, a cat already saved
10. you name the cat and tap Continue: Starter tasks, a cat already saved
11. you tap Start: Saving your first cat
12. the cat and tasks are written: Home with two first cats

## Rules that hold
TypeOK, HomeHasCatUnlessChosen, NoDeadlock
