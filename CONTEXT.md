# CatCareCalendar Domain Context

CatCareCalendar is a local-first iOS app for cat owners. It tracks the recurring care work a
household owes its cats, and it tells the household when that work is due.

## Language

**Care Task**:
A unit of care work owed to one or more cats — a feeding, a medication dose, a grooming session, a
vet visit. It may stand alone or repeat under a recurrence rule.
_Avoid_: chore, todo, item, activity

**Starter Task**:
A care task that onboarding creates for a household's first cat — feeding, water, or litter box —
from fixed starting values the household picks during setup. Once created it is an ordinary care
task, made by the same rules as one added by hand.
_Avoid_: default task, sample task, seed (seeding is test fixture data, not household data)

**Recurrence Rule**:
The rule that says when a care task falls due again: how often it repeats, on which weekdays, at
what time of day, and until when. A task with no repetition has a one-time rule. The recurrence rule
answers "when is this task next due"; reminders are derived from its answers.
_Avoid_: schedule (it also means "schedule a reminder"), repeat configuration, frequency (one part of the rule)

**Overdue**:
A care task is overdue when its due time has passed and the work is still open (pending or in
progress). The due time counts, not the due day: a task due today at 09:00 is overdue at 09:01.
One clock decides it, the same for every screen.
_Avoid_: late, missed, past due (one word for one rule)

**Reminder**:
A scheduled alert that tells a caregiver a care task is due. The app delivers a reminder as a local
notification, so "notification" names the delivery mechanism and "reminder" names the thing the
household cares about.
_Avoid_: notification (when you mean the domain concept), alert, push

**Quick Action**:
A Home dashboard shortcut that routes into an existing creation or management flow.

**Assistant Suggestion**:
A task proposed by the Task Assistant as a fast way to begin a task-related conversation. Selecting
one asks for confirmation in the conversation; it does not complete work immediately.

**Task Assistant**:
A conversational surface for finding, opening, postponing, or completing care tasks through the same
task-action rules used elsewhere in the app.
