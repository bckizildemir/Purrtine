import Foundation

enum TaskAssistantCommandKind {
    case complete
    case postpone
    case open
}

enum TaskAssistantResponseFormatting {
    static func confirmationTitle(for command: TaskAssistantCommandKind) -> String {
        switch command {
        case .complete:
            return String(localized: .taskAssistantConfirmCompletion)
        case .postpone:
            return String(localized: .taskAssistantConfirmPostpone)
        case .open:
            return String(localized: .taskAssistantConfirmOpen)
        }
    }

    static func clarificationMessage(for command: TaskAssistantCommandKind) -> String {
        switch command {
        case .complete:
            return String(localized: .taskAssistantClarifyCompletion)
        case .postpone:
            return String(localized: .taskAssistantClarifyPostpone)
        case .open:
            return String(localized: .taskAssistantClarifyOpen)
        }
    }

    static func confirmationMessage(for action: TaskAssistantAction) -> String {
        switch action {
        case .complete(let task, let completedForDate, _, let cats):
            let catNames = (cats.isEmpty ? task.assignedCats : cats).map(\.name).joined(separator: ", ")
            if let completedForDate {
                return String(localized: .taskAssistantConfirmCompletionMessage(task.title, catNames.isEmpty ? String(localized: .tasksConfigAllCats) : catNames, completedForDate.formatted(date: .abbreviated, time: .omitted)))
            }

            return String(localized: .taskAssistantConfirmCompletionToday(task.title, catNames.isEmpty ? String(localized: .tasksConfigAllCats) : catNames))

        case .postpone(let task, let minutes):
            return String(localized: .taskAssistantConfirmPostponeMessage(task.title, Int32(minutes)))

        case .open(let task):
            return String(localized: .taskAssistantConfirmOpenMessage(task.title))
        }
    }
}
