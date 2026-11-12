---- MODULE DailyCare ----
\* Purrtine: one daily task for one cat goes due and is completed.
\* Source: verify-purrtine features complete-task.md, notification-tap.md, whiskers.md;
\* Purrtine/Utilities/CareTaskWriter.swift (complete and delete drop the task's snoozes).
EXTENDS Naturals
VARIABLES screen, occ, snoozed, history
vars == <<screen, occ, snoozed, history>>
\* occ: today's occurrence is "waiting" (not due yet), "due", or "done" (moved to Tomorrow).
\* history: completions recorded for today's occurrence.

Init == screen = "home" /\ occ = "waiting" /\ snoozed = FALSE /\ history = 0

Complete == occ = "due" /\ occ' = "done" /\ snoozed' = FALSE /\ history' = history + 1

TimeComes == screen = "home" /\ occ = "waiting" /\ occ' = "due" /\ screen' = "banner"
             /\ UNCHANGED <<snoozed, history>>
SnoozeFires == screen = "home" /\ occ = "due" /\ snoozed /\ snoozed' = FALSE /\ screen' = "banner"
               /\ UNCHANGED <<occ, history>>
BannerGoesAway == screen = "banner" /\ screen' = "home" /\ UNCHANGED <<occ, snoozed, history>>
BannerSnooze == screen = "banner" /\ screen' = "home" /\ snoozed' = TRUE /\ UNCHANGED <<occ, history>>
BannerComplete == screen = "banner" /\ screen' = "home" /\ Complete
BannerTap == screen = "banner" /\ screen' = "edit" /\ UNCHANGED <<occ, snoozed, history>>
CloseEdit == screen = "edit" /\ screen' = "tasks" /\ UNCHANGED <<occ, snoozed, history>>
OpenTasks == screen = "home" /\ occ # "waiting" /\ screen' = "tasks" /\ UNCHANGED <<occ, snoozed, history>>
TasksToHome == screen = "tasks" /\ screen' = "home" /\ UNCHANGED <<occ, snoozed, history>>
CompleteInList == screen = "tasks" /\ UNCHANGED screen /\ Complete
OpenWhiskers == screen = "home" /\ occ # "waiting" /\ screen' = "whiskers" /\ UNCHANGED <<occ, snoozed, history>>
WhiskersToHome == screen \in {"whiskers", "chat"} /\ screen' = "home" /\ UNCHANGED <<occ, snoozed, history>>
\* The welcome screen shows a chip only for a task due today or overdue.
TapChip == screen = "whiskers" /\ occ = "due" /\ screen' = "confirm" /\ UNCHANGED <<occ, snoozed, history>>
ConfirmCard == screen = "confirm" /\ screen' = "chat" /\ Complete
CancelCard == screen = "confirm" /\ screen' = "chat" /\ UNCHANGED <<occ, snoozed, history>>
NextDay == screen = "home" /\ occ = "done" /\ occ' = "waiting" /\ history' = 0
           /\ UNCHANGED <<screen, snoozed>>

Next == TimeComes \/ SnoozeFires \/ BannerGoesAway \/ BannerSnooze \/ BannerComplete \/ BannerTap
        \/ CloseEdit \/ OpenTasks \/ TasksToHome \/ CompleteInList \/ OpenWhiskers \/ WhiskersToHome
        \/ TapChip \/ ConfirmCard \/ CancelCard \/ NextDay

\* Rules
NoReminderAfterDone == occ = "done" => ~snoozed
DoneIsInHistoryOnce == history = (IF occ = "done" THEN 1 ELSE 0)
====
