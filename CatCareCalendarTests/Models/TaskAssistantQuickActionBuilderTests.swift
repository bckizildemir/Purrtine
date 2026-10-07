import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct TaskAssistantQuickActionBuilderTests {
    @Test
    func overdueTasksSortBeforeTasksDueToday() throws {
        let fixture = try makeFixture()
        let chips = TaskAssistantQuickActionBuilder.chips(from: fixture.tasks, referenceDate: fixture.now)

        #expect(chips.map(\.title) == ["Overdue Feeding", "Due Today Litter"])
    }

    @Test
    func capsAtLimit() throws {
        let fixture = try makeFixture()
        let chips = TaskAssistantQuickActionBuilder.chips(from: fixture.tasks, referenceDate: fixture.now, limit: 1)

        #expect(chips.count == 1)
        #expect(chips.first?.title == "Overdue Feeding")
    }

    @Test(arguments: [0, -1, Int.min])
    func nonPositiveLimitReturnsNoChips(limit: Int) throws {
        let fixture = try makeFixture()

        let chips = TaskAssistantQuickActionBuilder.chips(
            from: fixture.tasks,
            referenceDate: fixture.now,
            limit: limit
        )

        #expect(chips.isEmpty)
    }

    @Test
    func excludesCompletedCancelledAndTasksWithoutDueDate() throws {
        let fixture = try makeFixture()
        let chips = TaskAssistantQuickActionBuilder.chips(from: fixture.tasks, referenceDate: fixture.now)

        let titles = Set(chips.map(\.title))
        #expect(titles.contains("Completed Task") == false)
        #expect(titles.contains("Cancelled Task") == false)
        #expect(titles.contains("No Due Date Task") == false)
        #expect(titles.contains("Future Task") == false)
    }

    @Test
    func mappedActionsAreAlwaysComplete() throws {
        let fixture = try makeFixture()
        let chips = TaskAssistantQuickActionBuilder.chips(from: fixture.tasks, referenceDate: fixture.now)

        #expect(chips.isEmpty == false)
        for chip in chips {
            guard case .complete = chip.action else {
                Issue.record("Expected a complete action for \(chip.title)")
                continue
            }
        }
    }

    private func makeFixture() throws -> (container: ModelContainer, tasks: [CareTask], now: Date) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)

        func makeTask(title: String, status: CareTaskStatus, daysFromToday: Int?) -> CareTask {
            let task = CareTask(title: title, category: .general, status: status)
            if let daysFromToday {
                let scheduledDate = Calendar.current.date(byAdding: .day, value: daysFromToday, to: today) ?? today
                let schedule = CareTaskSchedule(scheduledDate: scheduledDate)
                schedule.task = task
                task.schedules = [schedule]
            }
            return task
        }

        let overdueFeeding = makeTask(title: "Overdue Feeding", status: .pending, daysFromToday: -1)
        let dueTodayLitter = makeTask(title: "Due Today Litter", status: .pending, daysFromToday: 0)
        let futureTask = makeTask(title: "Future Task", status: .pending, daysFromToday: 3)
        let completedTask = makeTask(title: "Completed Task", status: .completed, daysFromToday: -2)
        let cancelledTask = makeTask(title: "Cancelled Task", status: .cancelled, daysFromToday: -2)
        let noDueDateTask = makeTask(title: "No Due Date Task", status: .pending, daysFromToday: nil)

        let allTasks = [overdueFeeding, dueTodayLitter, futureTask, completedTask, cancelledTask, noDueDateTask]
        for task in allTasks {
            context.insert(task)
            for schedule in task.schedules {
                context.insert(schedule)
            }
        }
        try context.save()

        return (container, allTasks, now)
    }
}
