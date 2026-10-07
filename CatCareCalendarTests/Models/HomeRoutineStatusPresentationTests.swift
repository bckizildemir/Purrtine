import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct HomeRoutineStatusPresentationTests {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    @Test
    func rowsAreDerivedPerTaskNotPerCompletion() {
        let referenceDate = makeDate(year: 2026, month: 4, day: 7, hour: 12)

        let feedingTask = makeTask(
            title: "Feed Cats",
            dueDate: makeDate(year: 2026, month: 4, day: 8, hour: 8),
            completionDates: [
                makeDate(year: 2026, month: 4, day: 7, hour: 8),
                makeDate(year: 2026, month: 4, day: 6, hour: 8),
                makeDate(year: 2026, month: 4, day: 5, hour: 8),
                makeDate(year: 2026, month: 4, day: 4, hour: 8)
            ]
        )
        let litterTask = makeTask(
            title: "Change Litter",
            dueDate: makeDate(year: 2026, month: 4, day: 8, hour: 9),
            completionDates: [makeDate(year: 2026, month: 4, day: 2, hour: 9)]
        )
        let fountainTask = makeTask(
            title: "Clean Water Fountain",
            dueDate: makeDate(year: 2026, month: 4, day: 9, hour: 10),
            completionDates: [makeDate(year: 2026, month: 3, day: 23, hour: 10)]
        )

        let rows = HomeRoutineStatusPresentation.rows(
            from: [feedingTask, litterTask, fountainTask],
            referenceDate: referenceDate,
            locale: locale,
            calendar: makeCalendar()
        )

        let actualIDs = Set(rows.map(\.taskID))
        let expectedIDs: Set<UUID> = [feedingTask.id, litterTask.id, fountainTask.id]

        #expect(actualIDs == expectedIDs)
        #expect(rows.count == 3)
    }

    @Test
    func rowsExcludeTasksWithNoCompletionHistory() {
        let referenceDate = makeDate(year: 2026, month: 4, day: 7, hour: 12)

        let neverCompleted = makeTask(
            title: "Brush Teeth",
            dueDate: makeDate(year: 2026, month: 4, day: 12, hour: 9),
            completionDates: []
        )
        let completed = makeTask(
            title: "Feed Cats",
            dueDate: makeDate(year: 2026, month: 4, day: 8, hour: 8),
            completionDates: [makeDate(year: 2026, month: 4, day: 6, hour: 8)]
        )

        let rows = HomeRoutineStatusPresentation.rows(
            from: [neverCompleted, completed],
            referenceDate: referenceDate,
            locale: locale,
            calendar: makeCalendar()
        )

        #expect(rows.map(\.taskID) == [completed.id])
    }

    @Test
    func rowsSortByAttentionThenStaleCompletionAge() {
        let referenceDate = makeDate(year: 2026, month: 4, day: 7, hour: 12)

        let overdue = makeTask(
            title: "Clean Litter",
            dueDate: makeDate(year: 2026, month: 4, day: 5, hour: 9),
            completionDates: [makeDate(year: 2026, month: 4, day: 1, hour: 9)]
        )
        let dueToday = makeTask(
            title: "Feed Cats",
            dueDate: makeDate(year: 2026, month: 4, day: 7, hour: 18),
            completionDates: [makeDate(year: 2026, month: 4, day: 6, hour: 18)]
        )
        let dueTomorrow = makeTask(
            title: "Refresh Water",
            dueDate: makeDate(year: 2026, month: 4, day: 8, hour: 8),
            completionDates: [makeDate(year: 2026, month: 4, day: 6, hour: 8)]
        )
        let laterStale = makeTask(
            title: "Trim Nails",
            dueDate: makeDate(year: 2026, month: 4, day: 12, hour: 10),
            completionDates: [makeDate(year: 2026, month: 3, day: 20, hour: 10)]
        )
        let laterRecent = makeTask(
            title: "Play Time",
            dueDate: makeDate(year: 2026, month: 4, day: 11, hour: 10),
            completionDates: [makeDate(year: 2026, month: 4, day: 6, hour: 10)]
        )

        let rows = HomeRoutineStatusPresentation.rows(
            from: [laterRecent, dueTomorrow, overdue, laterStale, dueToday],
            referenceDate: referenceDate,
            locale: locale,
            calendar: makeCalendar()
        )

        let actualOrder = rows.map(\.taskID)
        let expectedOrder = [
            overdue.id,
            dueToday.id,
            dueTomorrow.id,
            laterStale.id,
            laterRecent.id
        ]

        #expect(actualOrder == expectedOrder)
    }

    @Test
    func rowsUseFullWordRelativeTime() throws {
        let referenceDate = makeDate(year: 2026, month: 4, day: 7, hour: 12)
        let staleTask = makeTask(
            title: "Clean Water Fountain",
            dueDate: makeDate(year: 2026, month: 4, day: 10, hour: 9),
            completionDates: [makeDate(year: 2026, month: 3, day: 23, hour: 9)]
        )

        let rows = HomeRoutineStatusPresentation.rows(
            from: [staleTask],
            referenceDate: referenceDate,
            locale: locale,
            calendar: makeCalendar()
        )

        let staleRow = try #require(rows.first { $0.taskID == staleTask.id })

        #expect(staleRow.primaryRecencyText.contains("15 days ago"))
        #expect(staleRow.primaryRecencyText.contains("15d") == false)
    }

    private func makeTask(
        title: String,
        dueDate: Date,
        completionDates: [Date]
    ) -> CareTask {
        let task = CareTask(title: title, iconName: "checkmark.circle")
        let schedule = CareTaskSchedule(scheduledDate: dueDate, frequency: .weekly)
        schedule.task = task
        task.schedules = [schedule]

        let completions = completionDates.map { completionDate in
            let completion = CareTaskCompletion(
                completedAt: completionDate,
                completedForDate: completionDate
            )
            completion.task = task
            return completion
        }

        task.completions = completions
        return task
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        let calendar = makeCalendar()
        return calendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        ) ?? .distantPast
    }
}
