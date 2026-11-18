import Foundation

enum TaskAssistantAction {
    /// `completedForDate` is the day the user named ("yesterday"), `nil` for the open day.
    /// `completedAtTime` is a time of day they stated for that day ("at 9"); it is read only with a day.
    case complete(
        task: CareTask,
        completedForDate: Date?,
        completedAtTime: TimeOfDay? = nil,
        notes: String?,
        cats: [Cat]
    )
    case postpone(task: CareTask, minutes: Int)
    case open(task: CareTask)

    var task: CareTask {
        switch self {
        case .complete(let task, _, _, _, _):
            return task
        case .postpone(let task, _):
            return task
        case .open(let task):
            return task
        }
    }
}
