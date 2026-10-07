import Foundation

/// What a caller knows about a completion beyond the task itself. Every field is optional: an
/// empty input completes the task for its assigned cats, by its caregiver, on its scheduled day.
struct CareTaskCompletionInput {
    var cats: [Cat] = []
    var caregiver: Caregiver?
    var completedForDate: Date?
    var notes: String?
    var photoURLs: [String] = []
}
