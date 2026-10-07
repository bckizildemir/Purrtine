import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct TaskCalendarDerivationTests {
    @Test
    func completedOneTimeTaskRemainsVisibleOnCompletedDay() async throws {
        let fixture = try makeFixture(frequency: .once, endDate: nil)

        try await fixture.sut.complete(fixture.task, with: CareTaskCompletionInput(), in: fixture.context)

        let completedDate = Calendar.current.startOfDay(for: fixture.schedule.scheduledDate)
        let tasksByDate = TaskCalendarDerivation.tasksByDate(from: [fixture.task], in: [completedDate])
        let tasksForDate = TaskCalendarDerivation.tasksForDate(completedDate, in: tasksByDate)

        #expect(tasksByDate[completedDate]?.map(\.id) == [fixture.task.id])
        #expect(tasksForDate.pending.isEmpty)
        #expect(tasksForDate.completed.map(\.id) == [fixture.task.id])
    }

    @Test
    func completedRecurringOccurrenceAppearsOnCompletedDayWithoutDuplicatingFutureDates() async throws {
        let fixture = try makeFixture(frequency: .daily, endDate: nil)
        let calendar = Calendar.current
        let completedDate = calendar.date(byAdding: .day, value: 3, to: fixture.schedule.scheduledDate) ?? fixture.schedule.scheduledDate
        let nextDate = calendar.date(byAdding: .day, value: 1, to: completedDate) ?? completedDate

        try await fixture.sut.complete(
            fixture.task,
            with: CareTaskCompletionInput(completedForDate: completedDate),
            in: fixture.context
        )

        let tasksByDate = TaskCalendarDerivation.tasksByDate(
            from: [fixture.task],
            in: [completedDate, nextDate]
        )
        let completedDay = TaskCalendarDerivation.tasksForDate(completedDate, in: tasksByDate)
        let nextDay = TaskCalendarDerivation.tasksForDate(nextDate, in: tasksByDate)

        #expect(tasksByDate.count == 2)
        #expect(completedDay.pending.isEmpty)
        #expect(completedDay.completed.map(\.id) == [fixture.task.id])
        #expect(nextDay.pending.map(\.id) == [fixture.task.id])
        #expect(nextDay.completed.isEmpty)
    }

    @Test
    func centurySpanningScheduleOnlyDerivesRequestedSparseDates() throws {
        let calendar = Self.gregorianCalendar()
        let firstDate = try #require(Self.date(1900, 1, 1, calendar: calendar))
        let secondDate = try #require(Self.date(1900, 1, 2, calendar: calendar))
        let sparseDate = try #require(Self.date(2090, 1, 1, calendar: calendar))
        let task = CareTask(title: "Daily medication")
        task.schedules = [
            CareTaskSchedule(
                scheduledDate: firstDate,
                frequency: .daily
            )
        ]

        let tasksByDate = TaskCalendarDerivation.tasksByDate(
            from: [task],
            in: [firstDate, sparseDate],
            calendar: calendar
        )

        #expect(Set(tasksByDate.keys) == [firstDate, sparseDate])
        #expect(tasksByDate[secondDate] == nil)
    }

    @Test
    func derivationUsesInjectedCalendarAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let daylightSavingDay = try #require(Self.date(2024, 3, 10, calendar: calendar))
        let nextDay = try #require(Self.date(2024, 3, 11, calendar: calendar))
        let task = CareTask(title: "Daily medication")
        task.schedules = [
            CareTaskSchedule(
                scheduledDate: daylightSavingDay,
                frequency: .daily
            )
        ]

        let tasksByDate = TaskCalendarDerivation.tasksByDate(
            from: [task],
            in: [daylightSavingDay, nextDay],
            calendar: calendar
        )

        #expect(tasksByDate[nextDay]?.map(\.id) == [task.id])
    }

    private func makeFixture(
        frequency: CareTaskFrequency,
        endDate: Date?
    ) throws -> (
        container: ModelContainer,
        context: ModelContext,
        task: CareTask,
        schedule: CareTaskSchedule,
        sut: any CareTaskWriting
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        let task = CareTask(title: "Feed Mochi")
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            frequency: frequency,
            frequencyInterval: 1,
            endDate: endDate,
            reminderMinutes: 15
        )

        task.assignedCaregiver = caregiver
        schedule.task = task
        task.schedules = [schedule]

        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        return (container, context, task, schedule, CareTaskWriter(scheduler: NotificationSchedulerSpy()))
    }

    private static func gregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
