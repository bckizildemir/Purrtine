import Foundation

/// What a task completion does when one of its photos cannot be saved.
nonisolated enum UnsavedPhotoPolicy: Sendable {
    /// Commit nothing and throw the `PhotoSaveError`, so the caregiver can choose what to do.
    case failCompletion
    /// Commit the completion with the photos that did save.
    case completeWithout
}
