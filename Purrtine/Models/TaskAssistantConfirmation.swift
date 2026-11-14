import Foundation

struct TaskAssistantConfirmation {
    let title: String
    let message: String
    let action: TaskAssistantAction
    /// For a completion: the day the task was due when the card was made. Confirming completes that
    /// day or nothing, so a task completed elsewhere in the meantime does not lose the next day.
    let openOccurrence: Date?

    init(title: String, message: String, action: TaskAssistantAction) {
        self.title = title
        self.message = message
        self.action = action
        if case .complete(let task, _, _, _) = action {
            openOccurrence = TaskActionService.openOccurrence(of: task)
        } else {
            openOccurrence = nil
        }
    }
}
