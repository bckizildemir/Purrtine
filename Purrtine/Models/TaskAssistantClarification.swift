import Foundation

struct TaskAssistantSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let action: TaskAssistantAction

    var task: CareTask {
        action.task
    }
}

struct TaskAssistantClarification {
    let message: String
    let suggestions: [TaskAssistantSuggestion]
}
