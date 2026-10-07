import Foundation

struct TaskAssistantCompletionRequest: Identifiable {
    let task: CareTask
    let completedForDate: Date?
    let initialNotes: String?
    let initialSelectedCats: [Cat]

    var id: UUID { task.id }
}
