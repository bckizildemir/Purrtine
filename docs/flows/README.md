# Purrtine user flows
Statecharts of the most important user flows, checked with TLA+ (TLC) and drawn with the `/statechart` skill on 2026-11-12. Each state is what the user sees; each arrow is what the user does. Every rule listed holds in the model. The models are read from the feature files of the verify skill and the code; they are not proof of the app (the verify skill is).
Make a chart again from its folder: `TLA2TOOLS=~/.local/share/tlaplus/tla2tools.jar ~/.claude/skills/statechart/scripts/statechart <Spec>.tla --config <Spec>.cfg --view view.mjs --out out`.

## Daily care

```mermaid
---
title: "Purrtine: daily care of one task"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: Waiting
    lg1: Due
    lg2: Done
  }
  class lg0 blue
  class lg1 orange
  class lg2 teal
  s0: Home, task not due yet
  s1: Reminder banner on screen
  s2: Home, done today, due tomorrow
  s3: Tasks tab with Edit Task sheet
  s4: Home, task due
  s5: Home, task due, reminder snoozed
  s6: Tasks list, task under Tomorrow
  s7: Whiskers, no chip
  s8: Tasks list, task due
  s9: Whiskers, with the task chip
  s10: Whiskers chat, Confirm Completion card
  s11: Whiskers chat, task is complete
  s12: Whiskers chat
  [*] --> s0
  s0 --> s1: the due time comes, a reminder shows
  s1 --> s2: you hold it and tap Complete
  s1 --> s3: you tap the reminder
  s1 --> s4: you ignore it
  s1 --> s5: you hold it and tap Remind in 10/30/60 min
  s2 --> s0: the next day comes
  s3 --> s8: you tap Cancel
  s4 --> s8: you open the Tasks tab
  s4 --> s9: you open Whiskers
  s5 --> s1: the snooze time comes
  s5 --> s8: you open the Tasks tab
  s6 --> s2: you open the Home tab
  s8 --> s6: you tap the circle (or swipe right, Complete)
  s9 --> s10: you tap the task chip
  s10 --> s11: you tap Confirm
  s10 --> s12: you tap Cancel
  s11 --> s2: you tap X, then Home
  s12 --> s4: you tap X, then Home
  s12 --> s5: you tap X, then Home
  class s0 blue
  class s1 orange
  class s2 teal
  class s3 orange
  class s4 orange
  class s5 orange
  class s6 teal
  class s7 teal
  class s8 orange
  class s9 orange
  class s10 orange
  class s11 teal
  class s12 orange
```

Rules and paths: [`4-daily-care/report.md`](4-daily-care/report.md).

## Add and manage

```mermaid
---
title: "Purrtine: add and manage a cat and a task"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: Cats
    lg1: Tasks
  }
  class lg0 purple
  class lg1 teal
  s0: My Cats, no Milo
  s1: Add New Cat, empty (Save off)
  s2: Add New Cat, name typed
  s3: Discard your changes?
  s4: My Cats, Milo listed
  s5: Edit Milo
  s6: Tasks list, no task
  s7: Delete this cat? alert
  s8: Add Task, empty
  s9: Add Task, title and cat set (Repeat Once)
  s10: Add Task, repeats daily
  s11: Tasks list, Brush coat listed
  s12: Edit Task
  [*] --> s0
  s0 --> s1: you tap +
  s1 --> s0: you tap Close
  s1 --> s2: you type a name
  s2 --> s3: you tap Close
  s2 --> s4: you tap Save
  s3 --> s0: you tap Discard Changes
  s4 --> s5: you tap Milo, Edit
  s4 --> s6: you open the Tasks tab
  s5 --> s7: you tap Delete Cat
  s6 --> s4: you open More, My Cats
  s6 --> s8: you tap +, Custom Task
  s7 --> s0: you tap Delete (its tasks go too)
  s8 --> s6: you tap Cancel
  s8 --> s9: you type a title and pick the cat
  s9 --> s10: you set Repeat to Daily
  s10 --> s11: you tap Save (reminders are set)
  s11 --> s6: you swipe left, Delete
  s11 --> s4: you open More, My Cats
  s11 --> s12: you tap the task
  s4 --> s11: you open the Tasks tab
  s12 --> s11: you tap Save or Cancel
  class s0 purple
  class s1 purple
  class s2 purple
  class s3 purple
  class s4 purple
  class s5 purple
  class s6 teal
  class s7 purple
  class s8 teal
  class s9 teal
  class s10 teal
  class s11 teal
  class s12 teal
```

Rules and paths: [`5-add-manage/report.md`](5-add-manage/report.md).
