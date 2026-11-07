import Foundation

struct TaskAssistantTaskChoice: Identifiable {
    let id = UUID()
    let task: CareTask
    let selectedCats: [Cat]
}

struct TaskAssistantTaskDisambiguation {
    let message: String
    let choices: [TaskAssistantTaskChoice]
    let completedForDate: Date?
    let notes: String?
}
