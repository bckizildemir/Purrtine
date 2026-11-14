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
