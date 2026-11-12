---------------------------- MODULE ReminderResync ----------------------------
(***************************************************************************)
(* The care-task reminder resync of Purrtine, at the granularity the code  *)
(* awaits. Every action names the Swift code it stands for.                *)
(*                                                                         *)
(* Pending set (iOS's pending notification requests):                     *)
(*   "rem"    one care-task reminder of an occurrence (task, occ, ver)     *)
(*   "nudge"  the one "open the app" nudge (app_open_nudge)                *)
(*   "snooze" a snooze_<taskId>_<ts> request, tagged with the occurrence   *)
(*            that was open when it was scheduled (ghost field occ)        *)
(*                                                                         *)
(* Scaled down: Limit stands for CareTaskReminderSelection.limit (59) and  *)
(* SnoozeSlots for the 4 snooze slots of its comment; the iOS cap is       *)
(* Limit + 1 + SnoozeSlots. Each open task offers one reminder candidate,  *)
(* the lower task number is "sooner".                                      *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Tasks,          \* task ids, numbers; lower number = sooner reminder
    CatOnlyTasks,   \* tasks only the deletable cat is on (the Cat.tasks cascade deletes them)
    Limit,          \* CareTaskReminderSelection.limit, scaled
    SnoozeSlots,    \* the snooze slots of the 64-slot budget, scaled
    MaxEvents,      \* bound on user and system events
    MaxSnoozes,     \* bound on snoozes added (taps count in MaxEvents too)
    MaxFetchFailures

Actors == {"app", "notif"}   \* the app's screens; the notification action handler

VARIABLES
    \* committed store (what a fresh ModelContext reads)
    alive, occ, ver,
    staged,         \* a failed task delete left staged in the main context (CareTaskWriter.delete catch)
    catGone,
    \* NotificationManager state
    settingsOn,     \* settings.isEnabled
    perm,           \* authorizationStatus as the app last read it: "unknown" | "on" | "off"
    sysPerm,        \* the permission in iOS Settings: "on" | "off"
    launched,       \* PurrtineApp's launch-time checkAuthorizationStatus has run
    pending,        \* iOS pending notification requests
    snoozeSeq,
    \* NotificationResyncCoordinator
    queued,         \* scheduleResync() was called; a pass is owed
    cancelled,      \* the pass in flight was cancelled by a newer request
    passPc, passInfo, passOn, passSnap, passToAdd,
    lastPass,       \* "none" | "running" | "ok" | "failed" | "cancelled": the newest pass
    remAtPassStart, \* ghost: the reminder part of pending when the pass started
    \* actors
    act,
    events, fetchFails

vars == <<alive, occ, ver, staged, catGone, settingsOn, perm, sysPerm, launched,
          pending, snoozeSeq, queued, cancelled, passPc, passInfo, passOn, passSnap,
          passToAdd, lastPass, remAtPassStart, act, events, fetchFails>>

Rec(k, t, o, v, n) == [kind |-> k, task |-> t, occ |-> o, ver |-> v, n |-> n]
Rem(t, o, v) == Rec("rem", t, o, v, 0)
Nudge == Rec("nudge", 0, 0, 0, 0)
Snooze(t, o, n) == Rec("snooze", t, o, 0, n)

Reminders(S) == {r \in S : r.kind \in {"rem", "nudge"}}
Snoozes(S) == {r \in S : r.kind = "snooze"}

RemindersOn == settingsOn /\ perm = "on"

\* NotificationManager.selectedReminderCandidates + CareTaskReminderSelection.soonest/nudgeFireDate:
\* the Limit soonest candidates of the open tasks, plus the nudge when the limit cut the set.
Derived(info, on) ==
    IF ~on THEN {}
    ELSE LET open == {t \in Tasks : info.alive[t]}
             sel  == {t \in open : Cardinality({u \in open : u < t}) < Limit}
         IN {Rem(t, info.occ[t], info.ver[t]) : t \in sel}
            \cup (IF Cardinality(open) > Limit THEN {Nudge} ELSE {})

Store == [alive |-> alive, occ |-> occ, ver |-> ver]

Idle == [pc |-> "idle", task |-> 0, occ |-> 0, snap |-> {}, then |-> "none"]

\* NotificationResyncCoordinator.scheduleResync(): cancel the pass in flight, owe a new one.
Request == queued' = TRUE /\ cancelled' = TRUE

NoRequest == UNCHANGED <<queued, cancelled>>

PassVars == <<passPc, passInfo, passOn, passSnap, passToAdd, lastPass, remAtPassStart, fetchFails>>
StoreVars == <<alive, occ, ver, staged, catGone>>

-----------------------------------------------------------------------------
Init ==
    /\ alive = [t \in Tasks |-> TRUE]
    /\ occ = [t \in Tasks |-> 0]
    /\ ver = [t \in Tasks |-> 0]
    /\ staged = [t \in Tasks |-> FALSE]
    /\ catGone = FALSE
    /\ settingsOn = TRUE
    /\ perm = "unknown"                 \* cold launch: nothing read yet
    /\ sysPerm = "on"
    /\ launched = FALSE
    \* the set the previous run of the app left behind
    /\ pending = Derived([alive |-> alive, occ |-> occ, ver |-> ver], TRUE)
    /\ snoozeSeq = 0
    /\ queued = FALSE
    /\ cancelled = FALSE
    /\ passPc = "idle"
    /\ passInfo = [alive |-> alive, occ |-> occ, ver |-> ver]
    /\ passOn = FALSE
    /\ passSnap = {}
    /\ passToAdd = {}
    /\ lastPass = "none"
    /\ remAtPassStart = {}
    /\ act = [a \in Actors |-> Idle]
    /\ events = 0
    /\ fetchFails = 0

-----------------------------------------------------------------------------
(* NotificationResyncCoordinator: one pass at a time (scheduleResync awaits *)
(* the previous task's result before it starts).                           *)

\* scheduleResync task body + resyncNow + activeScheduleInfos (NotificationResyncCoordinator.swift:39-87)
PassFetch ==
    /\ passPc = "idle" /\ queued
    /\ queued' = FALSE /\ cancelled' = FALSE
    /\ remAtPassStart' = Reminders(pending)
    /\ \/ \* fetchTasks throws: the pass throws before it touches the pending set
          /\ fetchFails < MaxFetchFailures
          /\ fetchFails' = fetchFails + 1
          /\ lastPass' = "failed"
          /\ UNCHANGED <<passPc, passInfo, passOn, passSnap, passToAdd, pending>>
       \/ /\ passInfo' = Store
          /\ passPc' = "auth"
          /\ lastPass' = "running"
          /\ UNCHANGED <<passOn, passSnap, passToAdd, fetchFails, pending>>
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, snoozeSeq, act, events>>

\* resyncCareTaskNotifications: `if authorizationStatus == .notDetermined { await updateAuthorizationStatus() }`,
\* then checkCancellation (NotificationManager.swift:385-388)
PassAuth ==
    /\ passPc = "auth"
    /\ perm' = IF perm = "unknown" THEN sysPerm ELSE perm
    /\ passPc' = IF cancelled THEN "idle" ELSE "read"
    /\ lastPass' = IF cancelled THEN "cancelled" ELSE lastPass
    /\ UNCHANGED <<StoreVars, settingsOn, sysPerm, launched, pending, snoozeSeq, queued, cancelled,
                   passInfo, passOn, passSnap, passToAdd, remAtPassStart, act, events, fetchFails>>

\* `let areRemindersOn = ...` then `await notificationCenter.pendingNotificationRequests()` (:390-394).
\* The read happens in this step; the code resumes in PassApply.
PassRead ==
    /\ passPc = "read"
    /\ passOn' = RemindersOn
    /\ passSnap' = pending
    /\ passPc' = "apply"
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, pending, snoozeSeq, queued, cancelled,
                   passInfo, passToAdd, lastPass, remAtPassStart, act, events, fetchFails>>

\* Resume: checkCancellation, compute the wanted set, remove the stale ids (:395-416).
\* Owned = care-task reminders and the nudge, and snoozes only when reminders are off.
PassApply ==
    /\ passPc = "apply"
    /\ IF cancelled
       THEN /\ passPc' = "idle" /\ lastPass' = "cancelled"
            /\ UNCHANGED <<pending, passToAdd>>
       ELSE LET owned  == {r \in passSnap : r.kind \in {"rem", "nudge"} \/ (~passOn /\ r.kind = "snooze")}
                wanted == Derived(passInfo, passOn /\ RemindersOn)
            IN /\ pending' = pending \ (owned \ wanted)
               /\ passToAdd' = wanted \ owned
               /\ passPc' = "add"
               /\ UNCHANGED lastPass
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, snoozeSeq, queued, cancelled,
                   passInfo, passOn, passSnap, remAtPassStart, act, events, fetchFails>>

\* The add loop: `try Task.checkCancellation(); try await notificationCenter.add(request)` (:423-432)
PassAdd ==
    /\ passPc = "add"
    /\ IF passToAdd = {}
       THEN /\ passPc' = "idle" /\ lastPass' = "ok"
            /\ UNCHANGED <<pending, passToAdd>>
       ELSE IF cancelled
       THEN /\ passPc' = "idle" /\ lastPass' = "cancelled"
            /\ UNCHANGED <<pending, passToAdd>>
       ELSE \E r \in passToAdd :
            /\ pending' = pending \cup {r}
            /\ passToAdd' = passToAdd \ {r}
            /\ UNCHANGED <<passPc, lastPass>>
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, snoozeSeq, queued, cancelled,
                   passInfo, passOn, passSnap, remAtPassStart, act, events, fetchFails>>

-----------------------------------------------------------------------------
(* CareTaskWriter verbs. Either actor can run complete; the notification   *)
(* handler (NotificationActionCoordinator.handle) also snoozes.            *)

CanAct(a) == act[a].pc = "idle" /\ events < MaxEvents

\* CareTaskWriter.complete: commit (recordCompletion + save), then cancelSnoozedNotifications (:88-96)
Complete(a, t) ==
    /\ CanAct(a) /\ alive[t] /\ ~staged[t]
    /\ occ' = [occ EXCEPT ![t] = @ + 1]
    /\ act' = [act EXCEPT ![a] = [Idle EXCEPT !.pc = "cs_read", !.task = t, !.then = "resync"]]
    /\ events' = events + 1
    /\ UNCHANGED <<alive, ver, staged, catGone, settingsOn, perm, sysPerm, launched, pending, snoozeSeq,
                   queued, cancelled, PassVars>>

\* CareTaskWriter.delete: the commit lands, or fails and stays staged with a watch armed (:66-77)
DeleteTask(t) ==
    /\ CanAct("app") /\ alive[t] /\ ~staged[t]
    /\ \/ /\ alive' = [alive EXCEPT ![t] = FALSE]
          /\ act' = [act EXCEPT !["app"] = [Idle EXCEPT !.pc = "cs_read", !.task = t, !.then = "resync"]]
          /\ UNCHANGED staged
       \/ /\ staged' = [staged EXCEPT ![t] = TRUE]
          /\ act' = [act EXCEPT !["app"] = [Idle EXCEPT !.pc = "cs_read", !.task = t, !.then = "none"]]
          /\ UNCHANGED alive
    /\ events' = events + 1
    /\ UNCHANGED <<occ, ver, catGone, settingsOn, perm, sysPerm, launched, pending, snoozeSeq,
                   queued, cancelled, PassVars>>

\* NotificationManager.cancelSnoozedNotifications: `await pendingNotificationRequests()` (:355)
CancelSnoozesRead(a) ==
    /\ act[a].pc = "cs_read"
    /\ act' = [act EXCEPT ![a].pc = "cs_remove",
                          ![a].snap = {r \in Snoozes(pending) : r.task = act[a].task}]
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, pending, snoozeSeq, queued, cancelled,
                   PassVars, events>>

\* ...removePendingNotificationRequests (:359), then the verb's resyncReminders (CareTaskWriter :79, :99)
CancelSnoozesRemove(a) ==
    /\ act[a].pc = "cs_remove"
    /\ pending' = pending \ act[a].snap
    /\ IF act[a].then = "resync" THEN Request ELSE NoRequest
    /\ act' = [act EXCEPT ![a] = Idle]
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, snoozeSeq, PassVars, events>>

\* CareTaskWriter.save after an edit of the recurrence rule. The save also lands every staged
\* delete, whose watch (watchForStagedDelete) asks for one more resync; requests coalesce.
EditSchedule(t) ==
    /\ CanAct("app") /\ alive[t] /\ ~staged[t]
    /\ ver' = [ver EXCEPT ![t] = @ + 1]
    /\ alive' = [u \in Tasks |-> alive[u] /\ ~staged[u]]
    /\ staged' = [u \in Tasks |-> FALSE]
    /\ Request
    /\ events' = events + 1
    /\ UNCHANGED <<occ, catGone, settingsOn, perm, sysPerm, launched, pending, snoozeSeq, act, PassVars>>

\* CatDeletionService.delete: commit (the cascade deletes the cat's own tasks), then
\* taskWriter.refreshReminders, a full resync (:96-116).
DeleteCat ==
    /\ CanAct("app") /\ ~catGone
    /\ catGone' = TRUE
    /\ alive' = [t \in Tasks |-> IF t \in CatOnlyTasks THEN FALSE ELSE alive[t]]
    /\ Request
    /\ events' = events + 1
    /\ UNCHANGED <<occ, ver, staged, settingsOn, perm, sysPerm, launched, pending, snoozeSeq, act, PassVars>>

\* NotificationManager.applySettings -> requestFullReminderResync
ToggleSettings ==
    /\ CanAct("app")
    /\ settingsOn' = ~settingsOn
    /\ Request
    /\ events' = events + 1
    /\ UNCHANGED <<StoreVars, perm, sysPerm, launched, pending, snoozeSeq, act, PassVars>>

\* The caregiver changes the permission in iOS Settings; the app learns it later.
ChangePermission ==
    /\ events < MaxEvents
    /\ sysPerm' = IF sysPerm = "on" THEN "off" ELSE "on"
    /\ events' = events + 1
    /\ UNCHANGED <<StoreVars, settingsOn, perm, launched, pending, snoozeSeq, queued, cancelled, act, PassVars>>

\* PurrtineApp init: checkAuthorizationStatus resyncs only when access changed.
LaunchPermissionCheck ==
    /\ ~launched
    /\ launched' = TRUE
    /\ perm' = sysPerm
    /\ IF (perm = "on") # (sysPerm = "on") \/ perm = "unknown" THEN Request ELSE NoRequest
    /\ UNCHANGED <<StoreVars, settingsOn, sysPerm, pending, snoozeSeq, act, PassVars, events>>

\* handleAppActivation: badge, updateAuthorizationStatus, requestFullReminderResync
AppActivation ==
    /\ CanAct("app")
    /\ perm' = sysPerm
    /\ Request
    /\ events' = events + 1
    /\ UNCHANGED <<StoreVars, settingsOn, sysPerm, launched, pending, snoozeSeq, act, PassVars>>

\* refreshAuthorizationStatusFromSystem: a change of access asks for a resync.
RefreshPerm ==
    /\ perm' = sysPerm
    /\ IF (perm = "on") # (sysPerm = "on") THEN Request ELSE NoRequest

\* A "Remind me" button on a delivered reminder: handle(.snooze) awaits the permission refresh
\* (NotificationActionCoordinator.swift:65).
SnoozeTap(t) ==
    /\ CanAct("notif") /\ snoozeSeq < MaxSnoozes 
    /\ act' = [act EXCEPT !["notif"] = [Idle EXCEPT !.pc = "sz_fetch", !.task = t]]
    /\ events' = events + 1
    /\ UNCHANGED <<StoreVars, settingsOn, perm, sysPerm, launched, pending, snoozeSeq, queued, cancelled, PassVars>>

\* Resume: the permission guard, fetchTask in a fresh context (committed store), then
\* CareTaskWriter.snooze -> scheduleSnoozedNotification awaits the permission again (:66-70).
SnoozeFetch ==
    /\ act["notif"].pc = "sz_fetch"
    /\ RefreshPerm
    /\ LET t == act["notif"].task IN
       act' = IF sysPerm = "on" /\ alive[t]
              THEN [act EXCEPT !["notif"].pc = "sz_add", !["notif"].occ = occ[t]]
              ELSE [act EXCEPT !["notif"] = Idle]
    /\ UNCHANGED <<StoreVars, settingsOn, sysPerm, launched, pending, snoozeSeq, PassVars, events>>

\* scheduleSnoozedNotification: permission check, then `try await notificationCenter.add(request)`
\* (NotificationManager.swift:753-765). No check of settings.isEnabled, of the task, or of a cap.
SnoozeAdd ==
    /\ act["notif"].pc = "sz_add"
    /\ RefreshPerm
    /\ IF sysPerm = "on"
       THEN /\ pending' = pending \cup {Snooze(act["notif"].task, act["notif"].occ, snoozeSeq)}
            /\ snoozeSeq' = snoozeSeq + 1
       ELSE UNCHANGED <<pending, snoozeSeq>>
    /\ act' = [act EXCEPT !["notif"] = Idle]
    /\ UNCHANGED <<StoreVars, settingsOn, sysPerm, launched, PassVars, events>>

Quiet ==
    /\ passPc = "idle" /\ ~queued
    /\ \A a \in Actors : act[a].pc = "idle"
    /\ launched

\* End state: nothing in flight. Lets TLC tell a real deadlock from the end of the bounded run.
Done == Quiet /\ UNCHANGED vars

Next ==
    \/ PassFetch \/ PassAuth \/ PassRead \/ PassApply \/ PassAdd
    \/ \E a \in Actors, t \in Tasks : Complete(a, t)
    \/ \E t \in Tasks : DeleteTask(t)
    \/ \E a \in Actors : CancelSnoozesRead(a) \/ CancelSnoozesRemove(a)
    \/ \E t \in Tasks : EditSchedule(t)
    \/ DeleteCat
    \/ ToggleSettings
    \/ ChangePermission
    \/ LaunchPermissionCheck
    \/ AppActivation
    \/ \E t \in Tasks : SnoozeTap(t)
    \/ SnoozeFetch
    \/ SnoozeAdd
    \/ Done

Spec == Init /\ [][Next]_vars

\* What TLC compares to tell two states apart: a pass's scratch values stop mattering once it is
\* idle (PassFetch overwrites them), and the ghost only matters after a failed read.
StateView ==
    <<alive, occ, ver, staged, catGone, settingsOn, perm, sysPerm, launched, pending, snoozeSeq,
      queued, passPc,
      IF passPc = "idle" THEN <<>> ELSE <<cancelled, passInfo, passOn, passSnap, passToAdd>>,
      lastPass, IF lastPass = "failed" THEN remAtPassStart ELSE {},
      act, events, fetchFails>>

-----------------------------------------------------------------------------
(* Rules                                                                    *)

\* "Converge": once nothing is in flight and the newest pass succeeded, the reminders and the
\* nudge are exactly the set derived from the committed store.
ConvergesToStore ==
    Quiet /\ lastPass = "ok" => Reminders(pending) = Derived(Store, RemindersOn)

\* A snooze never outlives its occurrence: not past a completion ...
NoSnoozeAfterCompletion ==
    Quiet => \A s \in Snoozes(pending) : alive[s.task] => occ[s.task] = s.occ

\* ... and not past the delete of its task.
NoSnoozeForDeletedTask ==
    Quiet => \A s \in Snoozes(pending) : alive[s.task] /\ ~staged[s.task]

\* Reminders off (settings or permission) means silence: nothing pending at all.
OffMeansSilent ==
    Quiet /\ lastPass = "ok" /\ ~RemindersOn => pending = {}

\* A failed store read never changes the pending reminders.
FailedReadKeepsSet ==
    lastPass = "failed" /\ passPc = "idle" => Reminders(pending) = remAtPassStart

\* The 64-slot budget: at most SnoozeSlots snoozes, and never more than iOS keeps.
SnoozesWithinSlots == Cardinality(Snoozes(pending)) <= SnoozeSlots
WithinIOSCap == Cardinality(pending) <= Limit + 1 + SnoozeSlots

=============================================================================
