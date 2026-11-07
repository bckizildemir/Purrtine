import Foundation

enum TaskAssistantIntentKind: Equatable {
    case open
    case complete
    case postpone
}

struct TaskAssistantIntentSelection {
    let task: CareTask
    let selectedCats: [Cat]
    let completedForDate: Date?
    let notes: String?

    /// Intents that make sense for the task's current status. Complete/postpone assume the
    /// task is still actionable — the same restriction `TaskAssistantViewModel.isValid` applies
    /// to a suggestion's pre-baked action — while opening a task's details is always valid.
    var availableIntents: [TaskAssistantIntentKind] {
        guard task.status != .completed && task.status != .cancelled else {
            return [.open]
        }
        return [.open, .complete, .postpone]
    }
}
