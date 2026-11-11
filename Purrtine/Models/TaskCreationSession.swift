import Foundation

/// The steps of the conversational "create a task" flow, in order. Each step is asked
/// as an assistant message; the answer is either typed (`.name`) or tapped from chips.
enum TaskCreationStep {
    case name
    case cats
    case category
    case repeatFrequency
    case time
    case confirm
}

/// A preset answer for the "what time?" step. The concrete `Date` is resolved by the
/// view model at selection time (it needs today's date); this stays a plain data option.
enum TaskCreationTimeOption: CaseIterable {
    case morning
    case noon
    case evening
    case none

    /// Hour of day for the preset, or `nil` for "no specific time".
    var hour: Int? {
        switch self {
        case .morning: return 8
        case .noon: return 12
        case .evening: return 18
        case .none: return nil
        }
    }
}

/// Holds the in-progress state of a conversational task creation. Kept as a plain value
/// type (separate from `TaskAssistantAction`, whose cases all require a resolved task) so
/// the assistant can accumulate answers across turns before persisting via
/// `TaskFormPersistence.createTask`.
struct TaskCreationSession {
    var step: TaskCreationStep = .name
    var title: String = ""
    var selectedCats: [Cat] = []
    var category: CareTaskCategory = .general
    var frequency: CareTaskFrequency = .once
    /// `nil` => no specific time (date-only task, no reminder).
    var scheduledTime: Date?
    /// Whether any cats existed when the flow began; when false the `.cats` step is skipped.
    var catsAvailable: Bool = true

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a `TaskFormDraft`, defaulting everything the conversation doesn't ask about
    /// to the Add Task form's defaults. A reminder is scheduled only when a time is chosen.
    func makeDraft() -> TaskFormDraft {
        TaskFormDraft(
            title: trimmedTitle,
            taskDescription: "",
            category: category,
            iconName: category.iconName,
            priority: .medium,
            assignedCats: selectedCats,
            assignedCaregiver: nil,
            scheduledDate: Date(),
            scheduledTime: scheduledTime,
            frequency: frequency,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: scheduledTime == nil ? nil : 0,
            customDays: nil
        )
    }
}
