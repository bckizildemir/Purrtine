import Foundation

/// What a caller knows about a completion beyond the task itself. Every field is optional: an
/// empty input completes the task for its assigned cats, by its caregiver, on its scheduled day.
struct CareTaskCompletionInput {
    var cats: [Cat] = []
    var caregiver: Caregiver?
    /// The day this completion counts for. `nil` is a plain tap: the real time, counted for the open day.
    var completedForDate: Date?
    /// A time of day the user stated for `completedForDate` ("yesterday at 9"). Read only with a named
    /// day; a time after now is refused (`TaskActionError.occurrenceNotOpen`).
    var completedAtTime: TimeOfDay?
    var notes: String?
    var photoURLs: [String] = []
    /// The occurrence the caller was shown, such as the day a reminder was made for. When the task's
    /// open occurrence is not that day, nothing is recorded (`TaskActionError.occurrenceNotOpen`).
    var expectedOccurrence: Date?
}
