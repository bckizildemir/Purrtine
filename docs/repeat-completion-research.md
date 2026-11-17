# Research: what a repeating task does when it is completed off-schedule

Date of research: 2026-11-16. Sources are vendor help pages, API references and Apple docs unless marked SECONDARY.
"Fetched" means the research agent opened the page and read the text itself. "Search-summary only" means it did not open the page.
Written by a research agent for the #1 grilling (2026-11-16). Not every quote was re-checked by a second reader: treat anything marked
SECONDARY or NOT VERIFIED as unconfirmed, and test Apple Reminders' real behavior on a device before relying on it.

## (a) Answer in one paragraph

Two models exist, and the serious apps offer BOTH as a per-task choice. (1) Fixed cadence: the next due date comes from the
scheduled date, so finishing late or early does not move the schedule (Todoist `every`, TickTick "By Due Dates", Things "Regularly",
OmniFocus "Assigned Dates", Due with a start date, Creatures default). (2) Repeat after completion: the next date is counted from the
day you actually did it (Todoist `every!`, TickTick "By Completion Dates", Things "After completion", OmniFocus "Completion", Due
"Completion date", Creatures "Count from the day it's completed"). Apple Reminders documents neither; its Mac/iPhone help pages
show no choice, and the only evidence that it follows the original schedule is a user forum (SECONDARY). Weekday lists
("every Monday and Thursday") are only documented in the fixed-cadence model: Things says weekday selection exists only for the
"Regularly" pattern, and Todoist says the next date comes from the task's date. No product page I could read says what happens
when you do the Monday dose on Wednesday; that case is undocumented everywhere. Backfilling with a chosen date/time is
documented for OmniFocus (editable Completed field), Streaks (tap any past day to set Completed/Missed/Skipped, day only, no clock
time), Apple Health Medications (pick a day, then Taken/Skipped; no documented clock time), and only via scripting/API for
Things and Todoist. EventKit stores `completionDate` separately from `dueDateComponents` and is schedule-based; it does not
document that a completion time ever moves the next due date.

## (b) Comparison table

| Product | Interval repeat, late/early | Weekday-list, done on an off day | Backfill with date/time | Source URL |
|---|---|---|---|---|
| Apple Reminders | NOT DOCUMENTED by Apple. No setting for "after completion" found in Apple help. Forum users say it follows the original due date (SECONDARY). | NOT DOCUMENTED. Apple says future instances are dimmed and can only be completed after the current one (Calendar app page). | Not documented. | https://support.apple.com/guide/iphone/iph14f1d32a5/ios ; https://support.apple.com/guide/reminders/add-dates-or-locations-to-reminders-remnd4b206fb/mac ; SECONDARY https://discussions.apple.com/thread/255872075 |
| Todoist | `every`: next date from the task's date, not completion day. `every!`: from completion day. User chooses by typing the word. | `every mon, thu` is valid. Docs do not describe completing on a non-listed day. Late completion does not skip an occurrence unless the next one has also passed. | No in-app backdate found. API `complete task` has optional `date_completed` (search-summary only, page not opened). | https://todoist.com/help/articles/introduction-to-recurring-due-dates-YUYVJJAV ; https://www.todoist.com/help/todoist/features/complete-a-task-with-a-recurring-date-dmI6SVqdP ; https://developer.todoist.com/api/v1/ |
| TickTick | "By Due Dates" = fixed. "By Completion Dates" = next from completion (every 3 days: done Sat instead of Fri -> next Tue; see note 1). Choice offered. | By Due Dates covers "every Friday at 13:00". Off-day completion not described. "Skip the recurrence" exists. | Not found. | https://help.ticktick.com/articles/7055782206349770752 |
| Things 3 | "Regularly": next copy on the fixed schedule, "regardless" of when you finish. "After completion": next copy counted from the finish day, same gap kept. Choice offered. | Weekday selection exists only for "Regularly". Done off-day: not described. Completing early (Aug 2026, v3.23): "Things will then schedule the next copy based on its existing rule". | Not in the app UI per the pages I read. URL scheme `completion-date` exists but "cannot be updated on repeating to-dos". Exact completion time shown in Get Info (search-summary only). | https://culturedcode.com/things/support/articles/3743733/ ; https://culturedcode.com/things/blog/2026/08/repeating-to-dos-refined/ ; https://culturedcode.com/things/support/articles/2803573/ |
| OmniFocus | "Completion": next from date and time completed, early or late alike. "Assigned Dates": next from scheduled date, early or late alike. Choice offered. | "Customize" for week/month exists. Off-day completion not described beyond the two rules above. | Yes: editable "Completed" date and time. For a repeating item, editing it after completing does NOT change the next occurrence (already created). Entering it in an empty Completed field generates the next occurrence from that entered time. | https://support.omnigroup.com/documentation/omnifocus/universal/4.3.3/en/the-inspector/ |
| Due | Per reminder: "From: Completion date" repeats from the day you mark done. Otherwise keeps its schedule (`recurfromdate`). Choice offered. | Not found. | Not found. | https://www.dueapp.com/support/osx/setting-a-reminder-that-repeats-from-the-date-of-completion.html ; https://www.dueapp.com/developer.html |
| Streaks | "Every 3 Days" (up to 60) exists. How the next due day is computed after a late/early completion: NOT DOCUMENTED in the pages I read. | Pages say Task Days "decides when you need to complete it". Off-day completion: not documented. | Yes, day only: long-press the task's mini-calendar, "tap any day to set it to COMPLETED, MISSED or SKIPPED". | https://streaks.app/help/task_edit_history/ ; https://streaks.app/help/ |
| Apple Health Medications | Not an interval-repeat task model in the docs I read. | n/a | Pick a day, mark Taken/Skipped; "log a medication, scheduled or unscheduled, at any time". Setting a clock time: NOT VERIFIED. | https://support.apple.com/guide/iphone/iph811670c81/ios |
| Creatures (pet app) | Default: repeats follow the original due date. Option "Count from the day it's completed". Choice offered. | Not described. | Not described. | https://help.creatures.com/en/article/reminders-and-upcoming-care-1fwvc8/ |

Note 1 (TickTick wording, fetched): "when the first exercise is on Tuesday, the second reminder will be on Friday (every three days).
However, if Wendy is delayed on Friday and can only complete the task on Saturday, the next reminder will be on Tuesday (three days
later)." That is the completion-based mode.

## Per-product evidence (quotes are short, from pages I fetched)

### Question 1: interval repeat, late or early

- Todoist: "The next date is calculated from the task's date, not from the day you complete it." (`every`)
  and "The next date is calculated from the day you complete the task." (`every!`). Example: `every! 3 months` done Jan 20 -> Apr 20.
  https://todoist.com/help/articles/introduction-to-recurring-due-dates-YUYVJJAV
  Also: "Completing a task a few days late, or moving it to an earlier date, won't skip an occurrence." Todoist skips only when you
  reschedule past the next occurrence or complete after the next occurrence has passed.
  https://www.todoist.com/help/todoist/features/complete-a-task-with-a-recurring-date-dmI6SVqdP
- TickTick: "By Due Dates" vs "By Completion Dates" are two separate Custom Repeat types. Completion repeat: "the next reminder time
  will change with the completion time." https://help.ticktick.com/articles/7055782206349770752
- Things 3: pattern "Regularly": "it doesn't matter if or when you complete the current copy"; bill example done on the 27th,
  "The next copy will appear on the 20th of the next month regardless." Warning: "If you miss a day, you'll end up with multiple
  copies stacking up in Today." Pattern "After completion": "a to-do is only repeated after you've checked off its current copy";
  late finish -> next copy from the finish day, "keeping the gap between repeats the same".
  https://culturedcode.com/things/support/articles/3743733/
  The page also says "Early completion: not addressed". Newer blog (Aug 2026): completing early via the checkbox, "Things will then
  schedule the next copy based on its existing rule" (for Regularly). Not stated for After completion.
  https://culturedcode.com/things/blog/2026/08/repeating-to-dos-refined/
- OmniFocus 4: Completion = "The next occurrence is based on the date and time that this occurrence is completed." Assigned Dates =
  "...based on the date and time that this occurrence was scheduled." And "Completing an item early or late works the same as
  completing it on time." https://support.omnigroup.com/documentation/omnifocus/universal/4.3.3/en/the-inspector/
  The label "Defer another" did NOT appear in the OmniFocus 4 page I fetched (only "Defer Until Date" as a schedule-from option).
  Older labels "Defer Another" / "Due Again" came from forum posts only (SECONDARY): https://discourse.omnigroup.com/t/repeat-every-versus-defer-another/32519
- Due: "Some reminders should repeat only from the date you mark them complete." Setting: From = "Completion date". URL scheme doc:
  "If unspecified, the recurrence will be repeat-from-completion" and "a yearly repeat-on-completion reminder will repeat again on June
  1st, 2012 if the user completes it on June 1st, 2011". https://www.dueapp.com/developer.html
- Apple Reminders: Apple help only describes how to set the repeat (Mac: Custom, Daily "Enter the number of days between each
  repeat"). Nothing on late completion. Forum (SECONDARY, community replies only, no Apple answer): users say Reminders repeats from the
  due date, and work around it by changing the due date to today before completing. https://discussions.apple.com/thread/255872075
- Streaks: lists "Every 3 Days - Or any other number of days, up to 60." Next-due rule after late completion: not stated.
  https://streaks.app/help/task-frequency/ was a 404 for the sub-page; the topic summary came from https://streaks.app/help/ (FAQ answer).

### Question 2: weekday list completed on another day

- Todoist: "every mon, fri" is listed as "Every Monday and Friday". "Tasks with time can't be set independently for each recurring day."
  Early/off-day completion is not described. https://todoist.com/help/articles/introduction-to-recurring-due-dates-YUYVJJAV
- Things: weekday picking exists for "Regularly" only ("you can select the exact days on which the to-do should repeat"; example Mon-Fri).
  Not available for "After completion". https://culturedcode.com/things/support/articles/3743733/
- OmniFocus, TickTick, Due, Streaks, Apple Reminders: no page I read describes an off-day completion of a weekday-list repeat.
  Apple Calendar page: future instances of a repeating reminder are dimmed and "can only be marked complete after the most current
  instance is marked complete." https://support.apple.com/guide/iphone/iph14f1d32a5/ios
- What apps record and show (completion time vs occurrence day): NOT VERIFIED for every product. Only these facts are documented:
  Todoist logs the day you completed (Reporting; completed occurrences can't be reopened or rescheduled, from a search summary of
  https://todoist.com/help/articles/view-the-activity-log-in-todoist-oOra6D, page not opened); OmniFocus keeps a Completed date/time.

### Question 3: backfill a past day

- OmniFocus: "Enter or edit a Completed date for the selected action". Setting a date on an active item completes it.
  For repeating items: entering "a date and time in an empty Completed field will generate the next occurrence" (based on the entered
  time) and "Completing a repeating item and then adjusting the Completed date will not change the next occurrence."
  https://support.omnigroup.com/documentation/omnifocus/universal/4.3.3/en/the-inspector/
- Streaks: "tap any day to set it to COMPLETED, MISSED or SKIPPED". Completed = filled circle, streak +1; Missed = X, streak resets to 0;
  Skipped = faded circle, streak unchanged. Day granularity only. https://streaks.app/help/task_edit_history/
- Apple Health Medications (iPhone guide): "You can log a medication, scheduled or unscheduled, at any time... Select a day, then...
  tap Taken or Skipped." History per medication is under Browse > Medications. The guide does not say you can type a clock time.
  https://support.apple.com/guide/iphone/iph811670c81/ios . The shorter article https://support.apple.com/en-us/105064 also says nothing about
  logged time or backdating.
- Things: URL scheme `completion-date` = ISO8601, "Ignored if the to-do is not completed or canceled, or if the date is in the future",
  "cannot be updated on repeating to-dos". https://culturedcode.com/things/support/articles/2803573/ . No UI backdating documented in what I read.
- Todoist: only the API is known to take a completion date (search-summary only). TickTick, Due, Apple Reminders: not found.

### Question 4: EventKit (via sosumi, Apple docs)

Documented:
- `EKReminder.dueDateComponents` (DateComponents?) is "The date by which the reminder should be completed." Gregorian calendar required;
  no hour/minute/second = all-day; on iOS a start date must be set if a due date is set.
  https://developer.apple.com/documentation/eventkit/ekreminder/duedatecomponents
- `EKReminder.completionDate` (Date?) is "The date on which the reminder was completed." Setting it to a date sets `isCompleted` true; setting nil
  sets false. https://developer.apple.com/documentation/eventkit/ekreminder/completiondate
- `isCompleted = true` sets `completionDate` to the current date; false sets it to nil. A reminder completed on another client can have
  `isCompleted` true but `completionDate` nil. https://developer.apple.com/documentation/eventkit/ekreminder/iscompleted
- So completion time and due date are two separate stored values. You can set a past completion date yourself.
- "Unlike with recurring events, only the first incomplete reminder of a recurring set is obtainable. This is true with EventKit as well as
  the Reminders app. When the reminder is completed, the next reminder in the recurrence set becomes available."
  https://developer.apple.com/documentation/eventkit/creating-a-recurring-event
  This is the only documented statement that completing a recurring reminder advances to the next one.
- `EKRecurrenceRule`: frequency (daily/weekly/monthly/yearly), `interval` (every N units), `daysOfTheWeek` (e.g. Tuesday and Friday), end by
  date or count. The rule is a schedule pattern. A rule cannot be modified; create a new one. `recurrenceRules` supports only one rule.
  https://developer.apple.com/documentation/eventkit/ekrecurrencerule ; https://developer.apple.com/documentation/eventkit/ekcalendaritem/recurrencerules
  Daily rules cannot take `days` (per the table in "Creating a recurring event"), so "every Monday and Thursday" is a weekly rule with two days.

NOT documented in Apple's pages (do not assume):
- Whether the next occurrence's due date is computed from the old due date or from `completionDate`. The docs describe a schedule-based rule
  and never mention completion-based repeat.
- Whether `completionDate` of a recurring reminder stays on the finished occurrence or on the series.
- What happens to a recurring reminder completed early or on a non-rule day.
- Whether completed past occurrences remain as separate EKReminder objects (the predicate `predicateForCompletedReminders(withCompletionDateStarting:ending:calendars:)`
  exists, but its page was not opened).

### Question 5: pet-care apps

- Creatures (help.creatures.com): default follows original due date; option "Count from the day it's completed". Page says nothing on early
  completion. Skip asks for a reason. https://help.creatures.com/en/article/reminders-and-upcoming-care-1fwvc8/
- 11pets, Petcube, Cat Tracker, PetDesk: no documentation found (the search returned no official help page for these on late/early completion).
  PetDesk only had a blog on medication reminders; I did not open it.

## (c) Recommendation for Purrtine (plain words)

1. Keep the plan fixed by default, and record the real time you did it. Litter every 2 days, food daily, pills on Monday and Thursday are
   routines tied to the calendar, not to your last visit. Every product that has a weekday list uses fixed cadence for it (Things allows
   weekdays only there). Fixed cadence is also what Apple Reminders appears to do (SECONDARY evidence).
   Trade-off: if litter is done a day late, the next one is still on the old day, so the cat may get litter two days in a row. That
   is correct for a cat that needs a schedule, but feels wrong to someone who wants a fresh two-day gap.
2. For "every N days/weeks" only, offer one switch per task: "Count from the day I did it" (Todoist `every!`, TickTick, Things, OmniFocus,
   Due and Creatures all offer exactly this). Default it OFF for feeding and medication, and consider ON as a suggestion for litter.
   Trade-off: one more setting to explain; the schedule slowly drifts, and a late dose becomes the new rhythm.
3. For weekday lists, do not offer "count from completion". A Wednesday completion of a Monday task should not move Thursday.
   The documented apps are silent here, so this is a product decision, not a market standard. Simple rule: a completion is attached to
   one occurrence (the nearest unfinished one, or the one the user picked), and the other occurrences stay where they are.
   Trade-off: needs a clear rule for "which occurrence did I just do", especially when Monday was missed and it is Wednesday.
4. Store two things separately: the occurrence it was for (due day) and the time it really happened (completion time). EventKit
   does the same (`dueDateComponents` and `completionDate`). Show the real time in history. Trade-off: two values to show, but it avoids
   losing the truth when someone backfills.
5. Backfill: let the user set the day AND clock time ("I did it yesterday at 9"). Streaks does day only; Apple Health pick-a-day with
   Taken/Skipped (clock time not documented); OmniFocus edits date and time. A backfilled completion should NOT move the next due date by
   itself, as OmniFocus does when you edit a Completed date after the fact. Trade-off: if the user forgets to log, the next due date can be
   wrong until they backfill; a visible "log earlier" action fixes this.
6. If a due occurrence is long missed, do not stack copies (Things warns this clutters Today). Todoist's approach is to skip an occurrence only when its next one has also passed; a similar "roll forward" rule is simplest.

## (d) What I could not verify

- Apple Reminders: how the next due date is computed after late/early completion. No Apple help page says; only a forum (SECONDARY).
  Behaviour needs a hands-on test.
- Apple Health Medications: whether the logged time can be set to a past clock time (the guide shows day selection plus Taken/Skipped only).
  Not stated in https://support.apple.com/guide/iphone/iph811670c81/ios or https://support.apple.com/en-us/105064.
- Streaks: the rule for the next due day of "Every N days" after a late completion; no page found.
- Due: iOS-specific help; version 1.5.1 prompt "based on due time or current time" came from a search summary of blog.dueapp.com, which returned 403.
  NOT VERIFIED.
- TickTick: backdating a completion; no page found. OmniFocus "Defer another" label in the current manual: not present in OmniFocus 4 page.
- Todoist: in-app backdating; the API `date_completed` parameter is search-summary only (page not opened). Todoist behaviour when an
  `every mon, thu` task is completed on Wednesday or Sunday.
- Things 3: completion-based repeat on completing early; the Things UI for editing a completion date; exact-time display in Get Info
  (search-summary only).
- All products: how an off-day weekday completion is recorded and shown (completion time vs occurrence day). Not documented by any
  vendor page I read; needs hands-on tests.
- EventKit: whether `completionDate` or `dueDateComponents` of the next occurrence changes on completion, and what survives of past
  occurrences. Not in Apple docs; needs a small test on a device.
- Pet apps 11pets, Petcube, Cat Tracker, PetDesk: no documentation found on late/early completion.
- Page dates: Things "Repeating To-Dos, Refined" (Aug 2026) is dated after my training data; I read it as fetched today.
