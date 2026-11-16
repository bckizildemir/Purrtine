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

    /// One fixed "now" (today 08:00) for a test, passed into the code under test, so a run across
    /// midnight cannot see two different days.
    private func fixedNow() throws -> Date {
        try #require(Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()))
    }

    /// A task whose schedule is due at 09:00 (`scheduledTime`) on `openDay`.
    private func makeTimedFixture(
        frequency: CareTaskFrequency,
        openDay: Date,
        customDays: [Int]? = nil,
        now: Date
    ) throws -> (container: ModelContainer, context: ModelContext, task: CareTask, schedule: CareTaskSchedule) {
        let calendar = Calendar.current
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let dueTime = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now))
        let task = CareTask(title: "Feed Mochi")
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
