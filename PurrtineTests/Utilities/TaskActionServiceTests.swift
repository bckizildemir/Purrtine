import Foundation
import SwiftData
import Testing
@testable import Purrtine

/// The completion rules alone. What a completion does to reminders is `CareTaskWriterTests`' job.
@MainActor
struct TaskActionServiceTests {
    @Test
    func completingOneTimeTaskCreatesCompletionAndDeactivatesTheSchedule() throws {
        let fixture = try makeFixture(frequency: .once, endDate: nil)
        let caregiver = try #require(fixture.caregiver)

        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        let completion = try #require(fixture.task.completions.first)
        let expectedCompletedForDate = Calendar.current.startOfDay(for: fixture.schedule.scheduledDate)

        #expect(fixture.task.completions.count == 1)
        #expect(completion.completedForDate == expectedCompletedForDate)
        #expect(completion.caregiver?.id == caregiver.id)
        #expect(completion.cats.map(\.id) == [fixture.cat.id])
        #expect(completion.wasOnTime)
        #expect(fixture.schedule.isActive == false)
        #expect(fixture.task.status == .completed)
    }

    @Test
    func completingRecurringTaskCreatesTheNextOccurrence() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)

        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        let activeSchedules = fixture.task.schedules.filter(\.isActive)
        let nextSchedule = try #require(activeSchedules.first)
        let expectedNextDate = Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate)

        #expect(fixture.task.completions.count == 1)
        #expect(fixture.schedule.isActive == false)
        #expect(activeSchedules.count == 1)
        #expect(nextSchedule.id != fixture.schedule.id)
        #expect(nextSchedule.scheduledDate == expectedNextDate)
        #expect(fixture.task.status == .pending)
    }

    @Test
    func completingTheOpenOccurrenceByExplicitDateSchedulesTheNextOccurrenceAfterIt() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let completedForDate = fixture.schedule.scheduledDate

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: completedForDate),
            in: fixture.context
        )

        let completion = try #require(fixture.task.completions.first)
        let nextSchedule = try #require(fixture.task.schedules.filter(\.isActive).first)
        // The replacement schedule keeps the original time of day, so it advances a day from the
        // completed occurrence itself — not from that occurrence's start-of-day.
        let expectedNextDate = calendar.date(byAdding: .day, value: 1, to: completedForDate)

        #expect(completion.completedForDate == calendar.startOfDay(for: completedForDate))
        #expect(nextSchedule.scheduledDate == expectedNextDate)
    }

    /// Calendar path: today is due, the caregiver completes tomorrow. Recording tomorrow would move
    /// the task to the day after and drop today's occurrence from the list, the calendar and the reminders.
    @Test
    func completingALaterDayThanTheOpenOneChangesNothing() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: tomorrow),
                in: fixture.context
            )
        }

        #expect(fixture.task.completions.isEmpty)
        #expect(fixture.task.schedules.filter(\.isActive).map(\.id) == [fixture.schedule.id])
    }

    /// Reminder and Whiskers path: the occurrence the caller saw is the pin. Yesterday was completed
    /// elsewhere, so yesterday's reminder must not complete today.
    @Test
    func anExpectedOccurrenceThatIsAlreadyCompletedRecordsNothing() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let yesterdaysOccurrence = fixture.schedule.scheduledDate
        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)
        let openSchedule = try #require(fixture.task.activeSchedule)

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(expectedOccurrence: yesterdaysOccurrence),
                in: fixture.context
            )
        }

        #expect(fixture.task.completions.count == 1)
        #expect(fixture.task.activeSchedule?.id == openSchedule.id)
    }

    /// Completing a later day's reminder while an earlier day is still open would skip the open day.
    @Test
    func anExpectedOccurrenceLaterThanTheOpenOneRecordsNothing() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(expectedOccurrence: tomorrow),
                in: fixture.context
            )
        }

        #expect(fixture.task.completions.isEmpty)
        #expect(fixture.task.activeSchedule?.id == fixture.schedule.id)
    }

    @Test
    func anExpectedOccurrenceThatIsOpenIsRecordedForThatDay() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(expectedOccurrence: fixture.schedule.scheduledDate),
            in: fixture.context
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedForDate == Calendar.current.startOfDay(for: fixture.schedule.scheduledDate))
        #expect(fixture.task.activeSchedule?.id != fixture.schedule.id)
    }

    @Test
    func anExpectedOccurrenceOnAnAlreadyCompletedOneTimeTaskRecordsNothing() throws {
        let fixture = try makeFixture(frequency: .once, endDate: nil)
        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(expectedOccurrence: fixture.schedule.scheduledDate),
                in: fixture.context
            )
        }

        #expect(fixture.task.completions.count == 1)
    }

    /// Whiskers path: "I fed her yesterday" after yesterday was completed in the list.
    @Test
    func recordingADayThatAlreadyHasACompletionRecordsNothing() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let completedDay = fixture.schedule.scheduledDate
        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: completedDay),
                in: fixture.context
            )
        }

        #expect(fixture.task.completions.count == 1)
    }

    /// `canComplete` is what a view asks before it opens a sheet for a day. It must say yes exactly
    /// when `recordCompletion` would accept that day: the day before the open one, the open day, and
    /// the day after it.
    @Test(arguments: [-1, 0, 1])
    func canCompleteAgreesWithRecordCompletion(dayOffset: Int) throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let day = try #require(Calendar.current.date(byAdding: .day, value: dayOffset, to: fixture.schedule.scheduledDate))
        let canComplete = TaskActionService.canComplete(fixture.task, on: day)

        var isRecorded = true
        do {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: day),
                in: fixture.context
            )
        } catch {
            isRecorded = false
        }

        #expect(canComplete == isRecorded)
        #expect(canComplete == (dayOffset <= 0))
    }

    @Test
    func canCompleteIsFalseForADayThatAlreadyHasACompletion() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let completedDay = fixture.schedule.scheduledDate
        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        #expect(TaskActionService.canComplete(fixture.task, on: completedDay) == false)
    }

    /// Owner decision 2 (#141): a missed day that is still open does not block completing a later
    /// day up to today. Yesterday is open (missed); the caregiver completes today.
    @Test
    func completingTodayWhileYesterdayIsOpenLeavesYesterdayMissed() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        fixture.schedule.scheduledDate = yesterday
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))

        #expect(TaskActionService.canComplete(fixture.task, on: today))
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context
        )

        #expect(fixture.task.completions.map(\.completedForDate) == [today])
        #expect(TaskCalendarDerivation.hasCompletion(for: fixture.task, on: calendar.startOfDay(for: yesterday), calendar: calendar) == false)
        let open = try #require(fixture.task.activeSchedule)
        #expect(calendar.startOfDay(for: open.scheduledDate) == tomorrow)
        #expect(fixture.task.schedules.filter(\.isActive).count == 1)
    }

    /// Yesterday is still open, so it can be completed on its own, and then the open day moves to today.
    @Test
    func theOpenMissedDayCanStillBeCompletedAndMovesTheOpenDayOn() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        fixture.schedule.scheduledDate = yesterday

        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        let open = try #require(fixture.task.activeSchedule)
        #expect(calendar.startOfDay(for: open.scheduledDate) == calendar.startOfDay(for: Date()))
    }

    /// After today was completed while yesterday was open, yesterday can still be filled in later
    /// (only through Whiskers "yesterday": the calendar shows nothing on a left-behind day); that
    /// must not pull the open day back from tomorrow.
    @Test
    func completingAnEarlierMissedDayLaterDoesNotMoveTheOpenDayBack() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        fixture.schedule.scheduledDate = yesterday
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context
        )

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context
        )

        #expect(fixture.task.completions.count == 2)
        let open = try #require(fixture.task.activeSchedule)
        #expect(calendar.startOfDay(for: open.scheduledDate) == tomorrow)
        #expect(fixture.task.schedules.filter(\.isActive).count == 1)
    }

    /// A day after today is refused even when an earlier day is open.
    @Test
    func aFutureDayIsRefusedWhileAnEarlierDayIsOpen() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        fixture.schedule.scheduledDate = yesterday
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: Date()))

        #expect(TaskActionService.canComplete(fixture.task, on: tomorrow) == false)
        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: tomorrow),
                in: fixture.context
            )
        }
        #expect(fixture.task.completions.isEmpty)
        #expect(fixture.task.activeSchedule?.id == fixture.schedule.id)
    }

    /// Today was completed with yesterday open; completing today again is refused.
    @Test
    func anAlreadyCompletedDayIsRefusedEvenWhenAnEarlierDayIsOpen() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        fixture.schedule.scheduledDate = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        let today = calendar.startOfDay(for: Date())
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context
        )

        #expect(TaskActionService.canComplete(fixture.task, on: today) == false)
        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: today),
                in: fixture.context
            )
        }
        #expect(fixture.task.completions.count == 1)
    }

    /// Decision 1 stays: a reminder names its day, and a day that is not the open one is refused,
    /// even though the same day passes as an explicit `completedForDate`.
    @Test
    func aReminderForALaterDayIsStillRefusedWhileAnEarlierDayIsOpen() throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        fixture.schedule.scheduledDate = try #require(calendar.date(byAdding: .day, value: -1, to: fixture.schedule.scheduledDate))
        let today = calendar.startOfDay(for: Date())

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(expectedOccurrence: today),
                in: fixture.context
            )
        }
        #expect(fixture.task.completions.isEmpty)
    }

    /// A weekly or custom-day task left behind on its first day: completing today (a later valid day)
    /// is accepted, records only today, and moves the open day to the next occurrence after today.
    @Test(arguments: [false, true])
    func completingALaterValidDayOfAWeeklyTaskLeavesTheEarlierDayBehind(usesCustomDays: Bool) throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let openDay = try #require(calendar.date(byAdding: .day, value: -4, to: today))
        let customDays = usesCustomDays
            ? [calendar.component(.weekday, from: today) - 1, calendar.component(.weekday, from: openDay) - 1]
            : nil
        let fixture = try makeTimedFixture(
            frequency: .weekly,
            openDay: openDay,
            customDays: customDays,
            now: now
        )
        // Both shapes next occur 3 days from today (every 7 days from the open day, or the second
        // custom weekday). An explicit day is accepted whether or not it is an occurrence.
        let expectedNext = try #require(calendar.date(byAdding: .day, value: 3, to: today))

        #expect(TaskActionService.canComplete(fixture.task, on: today, now: now))
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context,
            now: now
        )

        #expect(fixture.task.completions.map(\.completedForDate) == [today])
        let open = try #require(fixture.task.activeSchedule)
        #expect(fixture.task.schedules.filter(\.isActive).count == 1)
        #expect(calendar.startOfDay(for: open.scheduledDate) == expectedNext)
        #expect(TaskCalendarDerivation.hasCompletion(for: fixture.task, on: openDay, calendar: calendar) == false)
    }

    /// `canComplete` for a day before the open day: accepted while it has no completion, refused once
    /// it has one.
    @Test
    func canCompleteADayBeforeTheOpenDayUntilItHasACompletion() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)

        #expect(TaskActionService.canComplete(fixture.task, on: yesterday, now: now))
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context,
            now: now
        )

        #expect(TaskActionService.canComplete(fixture.task, on: yesterday, now: now) == false)
        let open = try #require(fixture.task.activeSchedule)
        #expect(calendar.startOfDay(for: open.scheduledDate) == today)
    }

    /// Daily 09:00, open since yesterday. Completing today at 08:00 is before today's due time.
    @Test
    func completingTodayBeforeTheDueTimeIsOnTimeEvenWhenYesterdayIsOpen() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: yesterday, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: calendar.startOfDay(for: now)),
            in: fixture.context,
            now: now
        )

        #expect(try #require(fixture.task.completions.first).wasOnTime)
    }

    /// Filling in a day before today is late, whatever the time of day.
    @Test
    func fillingInADayBeforeTodayIsLate() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let threeDaysAgo = try #require(calendar.date(byAdding: .day, value: -3, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: threeDaysAgo),
            in: fixture.context,
            now: now
        )

        #expect(try #require(fixture.task.completions.first).wasOnTime == false)
    }

    /// Whiskers' "fed Luna yesterday" while today is the open day: recorded for yesterday, and it
    /// must not make today's still-open occurrence look done.
    @Test
    func fillingInAnOlderDayDoesNotMakeTodayLookCompleted() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context,
            now: now
        )
        #expect(fixture.task.isCompletedToday(referenceDate: now) == false)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context,
            now: now
        )
        #expect(fixture.task.isCompletedToday(referenceDate: now))
    }

    /// Builds its own timed schedule instead of leaning on `makeFixture`, so the invariant survives
    /// any future change to the fixture's anchor. A midnight-anchored fixture is what previously let
    /// a same-day-repeat regression reach `main` unnoticed.
    @Test(arguments: [CareTaskFrequency.daily, .weekly, .biweekly, .monthly, .custom])
    func completingATimedRecurringScheduleAdvancesToALaterDay(
        frequency: CareTaskFrequency
    ) throws {
        let calendar = Calendar.current
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let anchorDate = try #require(
            calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: Date()))
        )
        let task = CareTask(title: "Feed Mochi")
        let schedule = CareTaskSchedule(
            scheduledDate: anchorDate,
            frequency: frequency,
            frequencyInterval: 1
        )
        schedule.task = task
        task.schedules = [schedule]
        context.insert(Caregiver(name: "Primary Caregiver", role: .primary))
        context.insert(task)
        context.insert(schedule)
        try context.save()

        try TaskActionService.recordCompletion(of: task, with: CareTaskCompletionInput(), in: context)

        let nextSchedule = try #require(task.schedules.filter(\.isActive).first)

        #expect(
            calendar.isDate(nextSchedule.scheduledDate, inSameDayAs: anchorDate) == false,
            "\(frequency) completion re-anchored on the completed day instead of advancing"
        )
        #expect(nextSchedule.scheduledDate > anchorDate)
    }

    @Test
    func detailedMultiCatCompletionPersistsSelectedCatsCaregiverNotesPhotosAndNormalizedDate() throws {
        let fixture = try makeFixture(frequency: .once, endDate: nil)
        let secondCat = Cat(name: "Luna")
        let selectedCaregiver = Caregiver(name: "Evening Caregiver", role: .member)
        fixture.task.assignedCats = [fixture.cat, secondCat]
        fixture.context.insert(secondCat)
        fixture.context.insert(selectedCaregiver)
        try fixture.context.save()

        let completedForDate = try #require(
            Calendar.current.date(
                bySettingHour: 18,
                minute: 45,
                second: 0,
                of: fixture.schedule.scheduledDate
            )
        )

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(
                cats: [secondCat],
                caregiver: selectedCaregiver,
                completedForDate: completedForDate,
                notes: "Luna ate half the portion.",
                photoURLs: ["proof-1.jpg", "proof-2.jpg"]
            ),
            in: fixture.context
        )

        let completion = try #require(fixture.task.completions.first)
        let expectedCompletedForDate = Calendar.current.startOfDay(for: completedForDate)

        #expect(fixture.task.completions.count == 1)
        #expect(completion.completedForDate == expectedCompletedForDate)
        #expect(completion.caregiver?.id == selectedCaregiver.id)
        #expect(completion.cats.map(\.id) == [secondCat.id])
        #expect(completion.notes == "Luna ate half the portion.")
        #expect(completion.photoURLs == ["proof-1.jpg", "proof-2.jpg"])
        #expect(fixture.schedule.isActive == false)
        #expect(fixture.task.status == .completed)
    }

    @Test
    func completingRecurringTaskWithoutFutureOccurrenceMarksTaskCompleted() throws {
        let fixture = try makeFixture(
            frequency: .daily,
            endDate: Calendar.current.startOfDay(for: Date())
        )

        try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        #expect(fixture.task.completions.count == 1)
        #expect(fixture.task.schedules.filter(\.isActive).isEmpty)
        #expect(fixture.task.status == .completed)
    }

    @Test
    func completingTaskWithoutAvailableCaregiverThrows() throws {
        let fixture = try makeFixture(
            frequency: .once,
            endDate: nil,
            includesCaregiver: false
        )

        #expect(throws: TaskActionError.caregiverUnavailable) {
            try TaskActionService.recordCompletion(of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context)
        }
        #expect(fixture.task.completions.isEmpty)
    }

    /// These messages reach the completion sheet alert and the Task Assistant, so each must come
    /// from the String Catalog. A hard-coded literal would fail here.
    @Test(arguments: [
        (TaskActionError.taskNotFound, String(localized: .errorTaskActionTaskNotFound)),
        (.caregiverUnavailable, String(localized: .errorTaskActionCaregiverUnavailable)),
        (.invalidPostponeMinutes, String(localized: .errorTaskActionInvalidPostponeMinutes)),
        (.occurrenceNotOpen, String(localized: .errorTaskActionOccurrenceNotOpen)),
    ])
    func errorDescriptionComesFromTheStringCatalog(error: TaskActionError, expected: String) {
        #expect(error.errorDescription == expected)
    }

    // MARK: - When the care was done (#163)

    /// Due two days ago, tapped today at 08:00 with no day named: the real time, counted for the open day.
    @Test
    func aPlainLateTapRecordsTheRealTimeAndCountsForTheOpenDay() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let openDay = try #require(calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: openDay, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == now)
        #expect(completion.completedForDate == openDay)
        #expect(completion.isFillIn() == false)
        #expect(completion.wasOnTime == false)
    }

    /// An early tap on a task due later still works: only a named day after today is refused.
    @Test
    func aPlainTapOnATaskDueLaterStillCompletesItsOpenDay() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let openDay = try #require(calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: openDay, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == now)
        #expect(completion.completedForDate == openDay)
        #expect(completion.isFillIn() == false)
    }

    /// "Yesterday" with no time, on a task with no time of its own: a fill-in.
    @Test
    func aNamedPastDayOnATimelessTaskIsAFillIn() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, hasDueTime: false, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == completion.completedForDate)
        #expect(completion.completedForDate == yesterday)
        #expect(completion.isFillIn())
    }

    /// "Yesterday" with no time, on a task due at 09:00: that day's due time, not a fill-in.
    @Test
    func aNamedPastDayOnATimedTaskIsDoneAtThatDaysDueTime() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == calendar.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday))
        #expect(completion.completedForDate == yesterday)
        #expect(completion.isFillIn() == false)
    }

    /// "Yesterday at 9:30" stores 09:30 whatever the task's own time, and is not a fill-in.
    @Test(arguments: [true, false])
    func aStatedTimeIsStoredOnTheNamedDayAndIsNotAFillIn(hasDueTime: Bool) throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, hasDueTime: hasDueTime, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: yesterday, completedAtTime: TimeOfDay(hour: 9, minute: 30)),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == calendar.date(bySettingHour: 9, minute: 30, second: 0, of: yesterday))
        #expect(completion.completedForDate == yesterday)
        #expect(completion.isFillIn() == false)
    }

    /// A time after `now` is refused. Today at 23:00 when it is 08:00.
    @Test
    func aStatedTimeAfterNowIsRefused() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)

        #expect(throws: TaskActionError.occurrenceNotOpen) {
            try TaskActionService.recordCompletion(
                of: fixture.task,
                with: CareTaskCompletionInput(completedForDate: today, completedAtTime: TimeOfDay(hour: 23, minute: 0)),
                in: fixture.context, now: now
            )
        }
        #expect(fixture.task.completions.isEmpty)

        // Earlier today is fine.
        try TaskActionService.recordCompletion(
            of: fixture.task,
            with: CareTaskCompletionInput(completedForDate: today, completedAtTime: TimeOfDay(hour: 7, minute: 30)),
            in: fixture.context, now: now
        )
        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today))
    }

    /// Today named with no time (the calendar, Whiskers "today") is the real time, not a fill-in.
    @Test
    func aNamedTodayWithNoTimeIsTheRealTime() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, hasDueTime: false, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == now)
        #expect(completion.isFillIn() == false)
    }

    /// A time with no named day is ignored: a plain tap is always the real time.
    @Test
    func aStatedTimeWithNoNamedDayIsIgnored() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let fixture = try makeTimedFixture(frequency: .daily, openDay: calendar.startOfDay(for: now), now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedAtTime: TimeOfDay(hour: 1, minute: 0)),
            in: fixture.context, now: now
        )

        #expect(try #require(fixture.task.completions.first).completedAt == now)
    }

    // MARK: - Which named days are accepted (#163)

    /// The task is 10 days old and due today. Any past day since it was created is accepted; the day
    /// before that, a day after today and a day already done are refused.
    @Test(arguments: [
        (dayOffset: -10, isAccepted: true),
        (dayOffset: -3, isAccepted: true),
        (dayOffset: 0, isAccepted: true),
        (dayOffset: -11, isAccepted: false),
        (dayOffset: 1, isAccepted: false)
    ])
    func aNamedDayIsAcceptedFromTheDayTheTaskWasCreated(dayOffset: Int, isAccepted: Bool) throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let day = try #require(calendar.date(byAdding: .day, value: dayOffset, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, createdDaysBeforeNow: 10, now: now)

        #expect(TaskActionService.canComplete(fixture.task, on: day, now: now) == isAccepted)
        if isAccepted {
            try TaskActionService.recordCompletion(
                of: fixture.task, with: CareTaskCompletionInput(completedForDate: day),
                in: fixture.context, now: now
            )
            #expect(fixture.task.completions.map(\.completedForDate) == [day])
        } else {
            #expect(throws: TaskActionError.occurrenceNotOpen) {
                try TaskActionService.recordCompletion(
                    of: fixture.task, with: CareTaskCompletionInput(completedForDate: day),
                    in: fixture.context, now: now
                )
            }
            #expect(fixture.task.completions.isEmpty)
        }
    }

    /// A task made today with a start date five days ago keeps its own first day: the bound is the
    /// earlier of the creation day and the open day.
    @Test(arguments: [(dayOffset: -5, isAccepted: true), (dayOffset: -6, isAccepted: false)])
    func aTaskCreatedWithAPastStartDateAcceptsItsOwnFirstDay(dayOffset: Int, isAccepted: Bool) throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let startDate = try #require(calendar.date(byAdding: .day, value: -5, to: today))
        let day = try #require(calendar.date(byAdding: .day, value: dayOffset, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: startDate, createdDaysBeforeNow: 0, now: now)

        #expect(TaskActionService.canComplete(fixture.task, on: day, now: now) == isAccepted)
    }

    @Test
    func aDayAlreadyDoneIsRefusedWhateverTheBound() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)
        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context, now: now
        )

        #expect(TaskActionService.canComplete(fixture.task, on: yesterday, now: now) == false)
    }

    /// The calendar shows the reason a day is refused, so it needs the reason, not only a yes or no.
    @Test
    func theCalendarReasonNamesWhyADayIsRefused() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let beforeCreation = try #require(calendar.date(byAdding: .day, value: -4, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, createdDaysBeforeNow: 3, now: now)
        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context, now: now
        )

        #expect(TaskActionService.completionRefusal(of: fixture.task, on: tomorrow, now: now) == .dayAfterToday)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: yesterday, now: now) == .alreadyDone)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: beforeCreation, now: now) == .beforeTaskExisted)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: today, now: now) == nil)
    }

    /// A stated time after now has its own reason, so Whiskers and the alert can say "that time hasn't
    /// come yet" instead of the catch-all text.
    @Test
    func aStatedTimeAfterNowHasItsOwnReason() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeTimedFixture(frequency: .daily, openDay: today, now: now)
        let evening = TimeOfDay(hour: 23, minute: 0)

        #expect(TaskActionService.completionRefusal(of: fixture.task, on: today, at: evening, now: now) == .timeAfterNow)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: today, at: TimeOfDay(hour: 7, minute: 30), now: now) == nil)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: yesterday, at: evening, now: now) == nil)
        #expect(TaskActionService.completionRefusal(of: fixture.task, on: tomorrow, at: evening, now: now) == .dayAfterToday)
        #expect(CompletionDayRefusal.timeAfterNow.message == String(localized: .taskCalendarRefusalTimeNotYet))
    }

    // MARK: - Weekday-list tasks (#163)

    /// Listed on two weekdays, due on the first, tapped on a day that is not listed: accepted, the real
    /// time is recorded, it counts for the open day, and the listed days stay.
    @Test
    func aWeekdayListTaskDoneOnAnotherDayCountsForTheOpenDayAndKeepsItsDays() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let openDay = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        let nextListedDay = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let customDays = [calendar.component(.weekday, from: openDay) - 1, calendar.component(.weekday, from: nextListedDay) - 1]
        let fixture = try makeTimedFixture(frequency: .weekly, openDay: openDay, customDays: customDays, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedAt == now)
        #expect(completion.completedForDate == openDay)
        #expect(completion.isFillIn() == false)
        let next = try #require(fixture.task.activeSchedule)
        #expect(calendar.startOfDay(for: next.scheduledDate) == nextListedDay)
        #expect(next.customDays == customDays)
    }

    /// A day the user names (Whiskers, calendar) on such a task is the day counted.
    @Test
    func aNamedDayOnAWeekdayListTaskIsTheDayCounted() throws {
        let calendar = Calendar.current
        let now = try fixedNow()
        let today = calendar.startOfDay(for: now)
        let openDay = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        let nextListedDay = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let customDays = [calendar.component(.weekday, from: openDay) - 1, calendar.component(.weekday, from: nextListedDay) - 1]
        let fixture = try makeTimedFixture(frequency: .weekly, openDay: openDay, customDays: customDays, now: now)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: today),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.completedForDate == today)
        #expect(completion.completedAt == now)
    }

    /// One fixed "now" (today 08:00) for a test, passed into the code under test, so a run across
    /// midnight cannot see two different days.
    private func fixedNow() throws -> Date {
        try #require(Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()))
    }

    /// A task whose schedule is due at 09:00 (`scheduledTime`) on `openDay`, or has no time of its own
    /// with `hasDueTime: false`. The task is `createdDaysBeforeNow` days old: a task that has existed
    /// a while, so a named past day is inside its life unless a test says otherwise.
    private func makeTimedFixture(
        frequency: CareTaskFrequency,
        openDay: Date,
        customDays: [Int]? = nil,
        hasDueTime: Bool = true,
        createdDaysBeforeNow: Int = 30,
        now: Date
    ) throws -> (container: ModelContainer, context: ModelContext, task: CareTask, schedule: CareTaskSchedule) {
        let calendar = Calendar.current
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let dueTime: Date? = hasDueTime ? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) : nil
        let task = CareTask(title: "Feed Mochi")
        task.createdAt = try #require(calendar.date(byAdding: .day, value: -createdDaysBeforeNow, to: now))
        let schedule = CareTaskSchedule(
            scheduledDate: calendar.startOfDay(for: openDay),
            scheduledTime: dueTime,
            frequency: frequency,
            frequencyInterval: 1,
            customDays: customDays
        )
        schedule.task = task
        task.schedules = [schedule]
        context.insert(Caregiver(name: "Primary Caregiver", role: .primary))
        context.insert(task)
        context.insert(schedule)
        try context.save()
        return (container, context, task, schedule)
    }

    private func makeFixture(
        frequency: CareTaskFrequency,
        endDate: Date?,
        includesCaregiver: Bool = true
    ) throws -> (
        container: ModelContainer,
        context: ModelContext,
        cat: Cat,
        caregiver: Caregiver?,
        task: CareTask,
        schedule: CareTaskSchedule
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let cat = Cat(name: "Mochi")
        let caregiver = includesCaregiver ? Caregiver(name: "Primary Caregiver", role: .primary) : nil
        let task = CareTask(title: "Feed Mochi")
        // A task that has existed a while, so a day before the open one is inside its life.
        task.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        // Anchored at 09:00 rather than midnight so the fixture matches the shape every real
        // schedule has — `OnboardingDataBuilder.dateToday(hour:)` stores the time of day in
        // `scheduledDate` and leaves `scheduledTime` nil. A midnight anchor makes a schedule's own
        // occurrence compare equal to the completed day, which hides same-day-repeat regressions
        // in recurrence advancement. Keep `scheduledTime` nil: it holds `effectiveDueDate` at
        // end-of-day, so `wasOnTime` stays true no matter what time the suite runs.
        let anchorDate = Calendar.current.date(
            byAdding: .hour,
            value: 9,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        let schedule = CareTaskSchedule(
            scheduledDate: anchorDate,
            frequency: frequency,
            frequencyInterval: 1,
            endDate: endDate,
            reminderMinutes: 15
        )

        task.assignedCats = [cat]
        task.assignedCaregiver = nil
        schedule.task = task
        task.schedules = [schedule]

        context.insert(cat)
        if let caregiver {
            context.insert(caregiver)
        }
        context.insert(task)
        context.insert(schedule)
        try context.save()

        return (container, context, cat, caregiver, task, schedule)
    }
}
