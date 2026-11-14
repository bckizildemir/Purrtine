import Foundation

/// What a caller knows about a completion beyond the task itself. Every field is optional: an
/// empty input completes the task for its assigned cats, by its caregiver, on its scheduled day.
struct CareTaskCompletionInput {
    var cats: [Cat] = []
    var caregiver: Caregiver?
    var completedForDate: Date?
    var notes: String?
    var photoURLs: [String] = []
    /// The occurrence the caller was shown, such as the day a reminder was made for. When the task's
    /// open occurrence is not that day, nothing is recorded (`TaskActionError.occurrenceNotOpen`).
    var expectedOccurrence: Date?
}
