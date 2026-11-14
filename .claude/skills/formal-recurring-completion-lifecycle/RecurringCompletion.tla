------------------------- MODULE RecurringCompletion -------------------------
(***************************************************************************)
(* The life of one recurring Care Task as caregivers complete it.          *)
(*                                                                         *)
(* Promise: completing a task either leaves exactly one active schedule    *)
(* that points to a strictly later occurrence, or closes the task; a       *)
(* completed occurrence never comes back and is never completed twice.     *)
(* Harm when it breaks: a task stuck on its first date, a task that        *)
(* vanishes, or doubled or missed care (a medication dose, a feeding).     *)
(*                                                                         *)
(* Time is counted in whole days (0 .. MaxDay). One daily schedule         *)
(* (frequency .daily, interval 1) with an end date on day EndDay.          *)
(* Every action names the code it stands for; read the SKILL.md coverage   *)
(* table before you change this file.                                      *)
(***************************************************************************)
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
    MaxDay,      \* last day the clock reaches
    EndDay,      \* CareTaskSchedule.endDate: the last day with an occurrence
    SharedTask,  \* TRUE: the task is assigned to two cats, FALSE: to one
    MaxDone,     \* bound: at most this many completions are explored
    MaxOpen,     \* bound: at most this many sources hold a request at once
    Sources,     \* which completion paths the run explores (a subset of AllSources)
    Editing      \* TRUE: the run includes the Edit Task form

None == -1

\* Where a completion comes from. Each holds at most one request at a time.
\*  "sheet"        TaskManagementView row -> TaskManagementViewModel.completeCareTask /
\*                 the completion sheet -> submitCompletion (completedForDate nil)
\*  "calendar"     TaskCalendarView.handleTaskCompletion (completedForDate = selectedDate)
\*  "assistant"    TaskAssistantViewModel.confirmPendingAction (.complete, completedForDate
\*                 nil / today / yesterday from TaskAssistantInterpreter.detectCompletionDate)
\*  "notification" the "Complete" action on a delivered reminder ->
\*                 NotificationActionCoordinator.handle(.complete) in its own ModelContext
AllSources == {"sheet", "calendar", "assistant", "notification"}
\* seen: the occurrence the caregiver saw; forDate: CareTaskCompletionInput.completedForDate;
\* expect: CareTaskCompletionInput.expectedOccurrence (#141), the day the caller was shown.
NoReq == [seen |-> None, forDate |-> None, expect |-> None]

VARIABLES
    today,          \* the current day
    exists,         \* the CareTask is in the store
    cats,           \* task.assignedCats.count
    status,         \* CareTask.status: "pending" or "completed"
    scheds,         \* CareTask.schedules, in array order: [day, active]
    done,           \* CareTask.completions: [for (completedForDate), seen, next]
    req,            \* per source: the request the user opened, NoReq when none
    removePending,  \* a writer completion has committed and not yet run
                    \* scheduler.removeDeliveredCareTaskNotifications
    form,           \* the edit form is open with this draft scheduledDate, None if closed
    start,          \* ghost: the first day the user asked for (create or edit)
    moved,          \* ghost: the days the user reopened in the edit form: the day moved to, and every
                    \* completed day on or after it
    undoOK          \* ghost: every failed commit left the task exactly as before

vars == <<today, exists, cats, status, scheds, done, req, removePending, form,
          start, moved, undoOK>>

Max(a, b) == IF a >= b THEN a ELSE b

(* CareTask.activeSchedules / activeSchedule (CareTask.swift:327-335):       *)
(* the active schedule with the earliest effectiveDueDate.                   *)
ActiveIdx == {i \in DOMAIN scheds : scheds[i].active}
HasActive == ActiveIdx /= {}
ActiveI   == CHOOSE i \in ActiveIdx : \A j \in ActiveIdx : scheds[i].day <= scheds[j].day
ActiveDay == IF HasActive THEN scheds[ActiveI].day ELSE None
DoneDays  == {done[i].for : i \in DOMAIN done}

(* CareTaskSchedule.nextOccurrence(from:) (CareTask.swift:478) for a daily   *)
(* schedule: nil when inactive, else the first occurrence on or after        *)
(* `from` (never before the anchor scheduledDate, fixedIntervalOccurrence    *)
(* clamps elapsed units at 0), nil past endDate.                             *)
NextOccurrence(s, from) ==
    IF ~s.active THEN None
    ELSE LET d == Max(s.day, from) IN IF d <= EndDay THEN d ELSE None

(* TaskActionService.completionDate(for:explicit:) (TaskActionService.swift:109) *)
CompletionDate(r) ==
    IF r.forDate /= None THEN r.forDate
    ELSE IF HasActive THEN ActiveDay
    ELSE today

(* TaskActionService.validateOccurrence (#141), run by recordCompletion before *)
(* anything is recorded: a named expected occurrence must be the open one; an  *)
(* explicit completedForDate must not be after the open day nor already done.  *)
Valid(r) ==
    /\ (r.expect /= None => (HasActive /\ ActiveDay = r.expect))
    /\ (r.forDate /= None =>
          /\ (HasActive => r.forDate <= ActiveDay)
          /\ r.forDate \notin DoneDays)

(* TaskActionService.recordCompletion + handleRecurringCompletion            *)
(* (TaskActionService.swift:34, :128). Returns the task after the change.    *)
Recorded(r, via) ==
    LET cfd   == CompletionDate(r)
        entry == [for |-> cfd, seen |-> r.seen]
    IN IF HasActive
       THEN LET a       == ActiveI
                \* resolved from the start of the day after the completed one,
                \* before isActive is cleared
                nxt     == NextOccurrence(scheds[a], cfd + 1)
                retired == [scheds EXCEPT ![a].active = FALSE]
            IN IF nxt /= None
               THEN [scheds |-> Append(retired, [day |-> nxt, active |-> TRUE]),
                     status |-> "pending",
                     done   |-> Append(done, entry @@ [next |-> nxt])]
               ELSE [scheds |-> retired,
                     status |-> "completed",
                     done   |-> Append(done, entry @@ [next |-> None])]
       \* no active schedule: `activeSchedule?.isActive = false` does nothing
       ELSE [scheds |-> scheds,
             status |-> "completed",
             done   |-> Append(done, entry @@ [next |-> None])]

(* CareTaskWriter.CompletionUndo.restore (CareTaskWriter.swift:235), with    *)
(* the values captured by init(capturing:) before recordCompletion ran.      *)
Restored(r) ==
    LET keptS == SubSeq(r.scheds, 1, Len(scheds))   \* drop added schedules
        keptD == SubSeq(r.done, 1, Len(done))       \* drop added completions
        \* activeSchedule?.isActive = wasActiveScheduleActive
        backS == IF HasActive THEN [keptS EXCEPT ![ActiveI].active = TRUE] ELSE keptS
    IN [scheds |-> backS, status |-> status, done |-> keptD]

-----------------------------------------------------------------------------
Init ==
    /\ today = 0
    /\ exists = TRUE
    /\ cats = IF SharedTask THEN 2 ELSE 1
    /\ status = "pending"
    /\ scheds = << [day |-> 0, active |-> TRUE] >>
    /\ done = << >>
    /\ req = [s \in AllSources |-> NoReq]
    /\ removePending = FALSE
    /\ form = None
    /\ start = 0
    /\ moved = {}
    /\ undoOK = TRUE

\* A new day begins.
DayPasses ==
    /\ today < MaxDay
    /\ today' = today + 1
    /\ UNCHANGED <<exists, cats, status, scheds, done, req, removePending, form,
                   start, moved, undoOK>>

\* --- A caregiver starts a completion (the request then waits for its commit) ---

\* Taps Complete on the task row, or opens the completion sheet (multi-cat).
TapCompleteInList ==
    /\ "sheet" \in Sources /\ form = None /\ exists /\ status = "pending" /\ req["sheet"] = NoReq
    /\ req["calendar"] = NoReq   \* one taskCompletionRequest at a time
    \* TaskCompletionRequest.expectedOccurrence (#141): the open day when the row or sheet was used
    /\ req' = [req EXCEPT !["sheet"] = [seen |-> ActiveDay, forDate |-> None, expect |-> ActiveDay]]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* Picks day d in the calendar, where TaskCalendarDerivation shows the task as
\* pending (an active schedule's nextOccurrence(from: d) falls on d, and
\* hasCompletionForDate is false), and taps Complete.
TapCompleteInCalendar ==
    /\ "calendar" \in Sources /\ form = None /\ exists /\ HasActive /\ req["calendar"] = NoReq
    /\ req["sheet"] = NoReq
    /\ \E d \in ActiveDay..EndDay :
          /\ d <= MaxDay
          /\ d \notin DoneDays
          /\ req' = [req EXCEPT !["calendar"] = [seen |-> d, forDate |-> d, expect |-> None]]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* Asks Whiskers to complete the task ("I fed her" / "... today" / "... yesterday");
\* the assistant shows the confirmation and waits.
AskWhiskersToComplete ==
    /\ "assistant" \in Sources /\ exists /\ status = "pending" /\ req["assistant"] = NoReq
    /\ \E f \in {None, today} \cup (IF today >= 1 THEN {today - 1} ELSE {}) :
          req' = [req EXCEPT !["assistant"] =
                    [seen |-> IF f = None THEN ActiveDay ELSE f, forDate |-> f,
                     \* TaskAssistantConfirmation.openOccurrence: the open day when the card was made
                     expect |-> ActiveDay]]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* The reminder for occurrence d fires. NotificationManager schedules the next
\* occurrences ahead (up to 30 for daily), so an unfinished earlier occurrence
\* does not stop a later reminder. Its userInfo carries the taskId and, since #141,
\* the occurrence date (NotificationManager.occurrenceDateKey), passed as expectedOccurrence.
ReminderFires ==
    /\ "notification" \in Sources /\ exists /\ HasActive
    /\ \E d \in ActiveDay..today :
          /\ d <= EndDay
          /\ req' = [req EXCEPT !["notification"] = [seen |-> d, forDate |-> None, expect |-> d]]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* --- The commit: recordCompletion and save() in one main-actor step ---

\* Edit Task is a modal sheet: while it is open the caregiver cannot submit the task
\* list's sheet, the calendar or Whiskers. Only a reminder action reaches the app then.
OnScreen(s) == form = None \/ s = "notification"

\* CareTaskWriter.complete: commit { recordCompletion } succeeds. Read against the
\* store as it is now (see SKILL.md: shared-store assumption).
CompletionSaved(s) ==
    /\ exists /\ req[s] /= NoReq /\ OnScreen(s) /\ Valid(req[s])
    /\ LET r == Recorded(req[s], s) IN
         /\ scheds' = r.scheds /\ status' = r.status /\ done' = r.done
    /\ req' = [req EXCEPT ![s] = NoReq]
    /\ removePending' = TRUE
    /\ UNCHANGED <<today, exists, cats, form, start, moved, undoOK>>

\* save() throws: CompletionUndo.restore runs. The sheet stays open for a retry;
\* the other sources report the failure and drop the request.
CompletionSaveFails(s) ==
    /\ exists /\ req[s] /= NoReq /\ OnScreen(s) /\ Valid(req[s])
    /\ LET back == Restored(Recorded(req[s], s)) IN
         /\ scheds' = back.scheds /\ status' = back.status /\ done' = back.done
         /\ undoOK' = (undoOK /\ back = [scheds |-> scheds, status |-> status, done |-> done])
    /\ req' = IF s = "sheet" THEN req ELSE [req EXCEPT ![s] = NoReq]
    /\ UNCHANGED <<today, exists, cats, removePending, form, start, moved>>

\* validateOccurrence throws TaskActionError.occurrenceNotOpen: nothing is recorded or staged.
\* Every source reports the failure and drops the request (the sheet shows the error too).
CompletionRefused(s) ==
    /\ exists /\ req[s] /= NoReq /\ OnScreen(s) /\ ~Valid(req[s])
    /\ req' = [req EXCEPT ![s] = NoReq]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* The request reaches a task that was deleted: fetchTask returns nil
\* (taskNotFound), or the stale main-context object no longer saves. Nothing is written.
CompletionFindsNoTask(s) ==
    /\ ~exists /\ req[s] /= NoReq
    /\ req' = [req EXCEPT ![s] = NoReq]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, removePending, form,
                   start, moved, undoOK>>

\* After the resync, CareTaskWriter.complete removes the task's delivered reminders.
DeliveredRemindersRemoved ==
    /\ removePending
    /\ removePending' = FALSE
    /\ req' = [req EXCEPT !["notification"] = NoReq]
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, form, start, moved, undoOK>>

\* --- Edit schedule: TaskFormPersistence.updateTask (TaskFormPersistence.swift:72) ---

TargetI == IF HasActive
           THEN CHOOSE i \in ActiveIdx : \A j \in ActiveIdx : i <= j  \* schedules.first(where: isActive)
           ELSE 1                                                    \* ?? schedules.first

OpenEditForm ==
    /\ Editing /\ exists /\ form = None
    /\ req["sheet"] = NoReq /\ req["calendar"] = NoReq   \* one sheet at a time
    /\ form' = scheds[TargetI].day
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, req, removePending,
                   start, moved, undoOK>>

\* Saves the form. The user keeps the shown date or picks today or later. Since #141 the
\* draft's scheduledDate is written onto the schedule active at save time only when the
\* user changed it (openedScheduledDate /= draft.scheduledDate); a kept date writes nothing.
SaveEditForm ==
    /\ exists /\ form /= None
    /\ \E nd \in ({form} \cup (today..EndDay)) :
          /\ scheds' = IF nd = form THEN scheds ELSE [scheds EXCEPT ![TargetI].day = nd]
          /\ start' = IF nd /= form /\ scheds[TargetI].active THEN nd ELSE start
          \* a move back onto or before a completed day reopens that day and every later one
          /\ moved' = IF nd /= form THEN moved \cup {d \in DoneDays \cup {nd} : d >= nd} ELSE moved
    /\ form' = None
    /\ UNCHANGED <<today, exists, cats, status, done, req, removePending, undoOK>>

CloseEditForm ==
    /\ form /= None
    /\ form' = None
    /\ UNCHANGED <<today, exists, cats, status, scheds, done, req, removePending,
                   start, moved, undoOK>>

\* --- Delete ---

\* CareTaskWriter.delete: the task and (cascade) its schedules and completions go.
DeleteTask ==
    /\ exists
    /\ exists' = FALSE /\ form' = None
    /\ UNCHANGED <<today, cats, status, scheds, done, req, removePending, start, moved, undoOK>>

\* CatDeletionService.delete (CatDeletionService.swift:80): a task with one cat is
\* deleted, a shared task loses the cat and keeps its schedules and completions.
DeleteCat ==
    /\ exists /\ cats >= 1
    /\ cats' = cats - 1
    /\ exists' = (cats > 1)
    /\ form' = IF cats > 1 THEN form ELSE None
    /\ UNCHANGED <<today, status, scheds, done, req, removePending, start, moved, undoOK>>

\* End state: the task is gone and nothing is left to happen.
Gone ==
    /\ ~exists /\ today = MaxDay /\ \A s \in Sources : req[s] = NoReq /\ ~removePending
    /\ UNCHANGED vars

Next ==
    \/ DayPasses
    \/ TapCompleteInList \/ TapCompleteInCalendar \/ AskWhiskersToComplete \/ ReminderFires
    \/ \E s \in Sources : CompletionSaved(s) \/ CompletionSaveFails(s) \/ CompletionRefused(s)
                          \/ CompletionFindsNoTask(s)
    \/ DeliveredRemindersRemoved
    \/ OpenEditForm \/ SaveEditForm \/ CloseEditForm
    \/ DeleteTask \/ DeleteCat
    \/ Gone

Spec == Init /\ [][Next]_vars

\* State bound for TLC (the "yesterday" and calendar paths can add completions forever).
Bounds ==
    /\ Len(done) <= MaxDone
    /\ Cardinality({s \in Sources : req[s] /= NoReq}) <= MaxOpen

-----------------------------------------------------------------------------
(* The rules. Each is one sentence in the SKILL.md table.                    *)

\* Pending means exactly one active schedule; closed means none.
OneActiveScheduleOrClosed ==
    exists =>
      /\ (status = "pending")   => Cardinality(ActiveIdx) = 1
      /\ (status = "completed") => ActiveIdx = {}

\* A completion that keeps the task open moves it to a strictly later day.
NextIsStrictlyLater ==
    \A i \in DOMAIN done : done[i].next = None \/ done[i].next > done[i].for

\* The day the task is due again is never a day already completed
\* (unless the user moved it there in the edit form).
CompletedNeverReappears ==
    (exists /\ status = "pending" /\ ActiveDay \notin moved) =>
        \A i \in DOMAIN done : done[i].for < ActiveDay

\* No occurrence carries two completions (unless the user moved the task back onto it).
NeverCompletedTwice ==
    \A i, j \in DOMAIN done : i < j => (done[i].for /= done[j].for \/ done[j].for \in moved)

\* The completion is recorded for the occurrence the caregiver saw and confirmed.
CompletesTheOccurrenceShown ==
    \A i \in DOMAIN done : done[i].for = done[i].seen

\* No occurrence between the first day asked for and the due day (or the end
\* day, once closed) disappears without a completion.
NoOccurrenceSkipped ==
    exists =>
      /\ (status = "pending")   => \A d \in start..(ActiveDay - 1) : d \in DoneDays
      /\ (status = "completed") => \A d \in start..EndDay : d \in DoneDays

\* A failed save leaves the task exactly as it was.
FailedSaveChangesNothing == undoOK

TypeOK ==
    /\ today \in 0..MaxDay
    /\ status \in {"pending", "completed"}
    /\ Sources \subseteq AllSources
    /\ \A s \in AllSources : req[s].seen \in (0..MaxDay) \cup {None}
    /\ \A s \in AllSources : req[s].expect \in (0..MaxDay) \cup {None}
=============================================================================
