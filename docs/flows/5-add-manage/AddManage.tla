---- MODULE AddManage ----
\* Purrtine: add a cat, add a task with a repeat and a reminder, edit it, delete the task, delete the cat.
\* Source: verify-purrtine features add-cat.md, add-task.md; Views/Cat/CatFormView.swift (delete alert),
\* Views/Tasks/TaskRowComponents.swift (swipe Delete, no confirm), Utilities/CatDeletionService.swift
\* (a cat's own tasks are deleted and their reminders cancelled).
\* Starts with no cat (the onboarding cat is left out); one cat, one task.
VARIABLES screen, cat, task, reminders, fName, fForm
vars == <<screen, cat, task, reminders, fName, fForm>>
\* fName: the Add Cat form has a name typed. fForm: Add Task form is "empty", "filled" (title+cat), "daily".

Init == screen = "cats" /\ cat = FALSE /\ task = FALSE /\ reminders = FALSE
        /\ fName = FALSE /\ fForm = "empty"

OpenAddCat == screen = "cats" /\ ~cat /\ screen' = "catform" /\ fName' = FALSE
              /\ UNCHANGED <<cat, task, reminders, fForm>>
TypeCatName == screen = "catform" /\ ~fName /\ fName' = TRUE /\ UNCHANGED <<screen, cat, task, reminders, fForm>>
\* Save stays disabled while the name is empty.
SaveCat == screen = "catform" /\ fName /\ screen' = "cats" /\ cat' = TRUE /\ UNCHANGED <<task, reminders, fName, fForm>>
CloseCatFormClean == screen = "catform" /\ ~fName /\ screen' = "cats" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
CloseCatFormChanged == screen = "catform" /\ fName /\ screen' = "discard" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
DiscardChanges == screen = "discard" /\ screen' = "cats" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
KeepEditing == screen = "discard" /\ screen' = "catform" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
GoToTasks == screen = "cats" /\ cat /\ screen' = "tasks" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
GoToCats == screen = "tasks" /\ screen' = "cats" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
\* The Tasks "+" menu is hidden while no cat exists.
OpenAddTask == screen = "tasks" /\ cat /\ ~task /\ screen' = "taskform" /\ fForm' = "empty"
               /\ UNCHANGED <<cat, task, reminders, fName>>
FillTitleAndCat == screen = "taskform" /\ fForm = "empty" /\ fForm' = "filled" /\ UNCHANGED <<screen, cat, task, reminders, fName>>
SetDaily == screen = "taskform" /\ fForm = "filled" /\ fForm' = "daily" /\ UNCHANGED <<screen, cat, task, reminders, fName>>
\* Save fails without a title or a cat. A Once task with the time off is due when the form
\* opened, so it gets no reminder (add-task.md); a daily task gets reminders.
SaveTask == screen = "taskform" /\ fForm # "empty" /\ screen' = "tasks" /\ task' = TRUE
            /\ reminders' = (fForm = "daily") /\ UNCHANGED <<cat, fName, fForm>>
CancelTaskForm == screen = "taskform" /\ screen' = "tasks" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
OpenEditTask == screen = "tasks" /\ task /\ screen' = "taskedit" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
CloseEditTask == screen = "taskedit" /\ screen' = "tasks" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
DeleteTask == screen = "tasks" /\ task /\ task' = FALSE /\ reminders' = FALSE /\ UNCHANGED <<screen, cat, fName, fForm>>
OpenEditCat == screen = "cats" /\ cat /\ screen' = "catedit" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
CloseEditCat == screen = "catedit" /\ screen' = "cats" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
AskDeleteCat == screen = "catedit" /\ screen' = "deletealert" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
CancelDeleteCat == screen = "deletealert" /\ screen' = "catedit" /\ UNCHANGED <<cat, task, reminders, fName, fForm>>
DeleteCat == screen = "deletealert" /\ screen' = "cats" /\ cat' = FALSE /\ task' = FALSE /\ reminders' = FALSE
             /\ UNCHANGED <<fName, fForm>>

Next == OpenAddCat \/ TypeCatName \/ SaveCat \/ CloseCatFormClean \/ CloseCatFormChanged
        \/ DiscardChanges \/ KeepEditing \/ GoToTasks \/ GoToCats \/ OpenAddTask \/ FillTitleAndCat
        \/ SetDaily \/ SaveTask \/ CancelTaskForm \/ OpenEditTask \/ CloseEditTask \/ DeleteTask
        \/ OpenEditCat \/ CloseEditCat \/ AskDeleteCat \/ CancelDeleteCat \/ DeleteCat

\* Rules
NoTaskWithoutCat == task => cat
NoReminderWithoutTask == reminders => task
AddTaskNeedsACat == screen = "taskform" => cat
====
