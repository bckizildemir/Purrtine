import Foundation

enum TaskAssistantAction {
    case complete(task: CareTask, completedForDate: Date?, notes: String?, cats: [Cat])
    case postpone(task: CareTask, minutes: Int)
    case open(task: CareTask)

    var task: CareTask {
        switch self {
        case .complete(let task, _, _, _):
            return task
        case .postpone(let task, _):
            return task
        case .open(let task):
            return task
        }
    }
}
