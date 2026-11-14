import Foundation

enum TaskCalendarDerivation {
    static func tasksByDate(
        from tasks: [CareTask],
        in dateRange: [Date],
        calendar: Calendar = .current
    ) -> [Date: [CareTask]] {
        guard dateRange.isEmpty == false else { return [:] }

        let normalizedDates = dateRange.map { calendar.startOfDay(for: $0) }
        let relevantDates = Set(normalizedDates)
        var result: [Date: [CareTask]] = [:]

        for task in tasks {
            for schedule in task.schedules.filter(\.isActive) {
                for date in relevantDates {
                    guard let occurrence = schedule.nextOccurrence(
                        from: date,
                        calendar: calendar
                    ),
                    calendar.isDate(occurrence, inSameDayAs: date) else {
                        continue
                    }
                    append(task, on: date, to: &result)
                }
            }

            for completion in task.completions {
                let completionDate = calendar.startOfDay(for: completion.completedForDate)
                guard relevantDates.contains(completionDate) else { continue }
                append(task, on: completionDate, to: &result)
            }
        }

        return result
    }

    static func tasksForDate(
        _ date: Date,
        in tasksByDate: [Date: [CareTask]],
        calendar: Calendar = .current
    ) -> (pending: [CareTask], completed: [CareTask]) {
        let targetDate = calendar.startOfDay(for: date)
        let allTasks = tasksByDate[targetDate] ?? []
        let pendingTasks = allTasks.filter { hasCompletion(for: $0, on: targetDate, calendar: calendar) == false }
        let completedTasks = allTasks.filter { hasCompletion(for: $0, on: targetDate, calendar: calendar) }
        return (pendingTasks, completedTasks)
    }

    static func hasCompletion(
        for task: CareTask,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let targetDate = calendar.startOfDay(for: date)
        return task.completions.contains { completion in
            calendar.isDate(calendar.startOfDay(for: completion.completedForDate), inSameDayAs: targetDate)
        }
    }

    private static func append(
        _ task: CareTask,
        on date: Date,
        to tasksByDate: inout [Date: [CareTask]]
    ) {
        if tasksByDate[date]?.contains(task) == true {
            return
        }

        tasksByDate[date, default: []].append(task)
    }
}
