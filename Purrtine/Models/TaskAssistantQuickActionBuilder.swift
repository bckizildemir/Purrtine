import Foundation

enum TaskAssistantQuickActionBuilder {
    static func chips(from tasks: [CareTask], referenceDate: Date = Date(), limit: Int = 3) -> [TaskAssistantSuggestion] {
        guard limit > 0 else { return [] }

        return tasks
            .filter { $0.status != .completed && $0.status != .cancelled }
            .filter { task in
                guard let dueDate = task.activeDueDate else { return false }
                return task.isOverdue || Calendar.current.isDate(dueDate, inSameDayAs: referenceDate)
            }
            .sorted { ($0.activeDueDate ?? .distantFuture) < ($1.activeDueDate ?? .distantFuture) }
            .prefix(limit)
            .map { task in
                TaskAssistantSuggestion(
                    title: task.title,
                    subtitle: task.dueDisplayText(relativeTo: referenceDate),
                    action: .complete(task: task, completedForDate: nil, notes: nil, cats: [])
                )
            }
    }
}
