import Foundation

struct TaskAssistantCompletionRequest: Identifiable {
    let task: CareTask
    let completedForDate: Date?
    /// A time of day the user stated for `completedForDate`; the sheet has no field for it.
    var completedAtTime: TimeOfDay?
    let initialNotes: String?
    let initialSelectedCats: [Cat]
    /// The day the task was due when the card was confirmed. Submitting the sheet completes that day
    /// or nothing, so a task completed elsewhere while the sheet was open does not lose its next day.
    var expectedOccurrence: Date?

    var id: UUID { task.id }
}
