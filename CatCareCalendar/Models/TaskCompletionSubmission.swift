import Foundation

/// The save state of the task completion sheet: one save at a time, and a readable alert message
/// when nothing was saved.
///
/// The sheet blocks Cancel and swipe-to-dismiss while `isSaving` is true, so every exit path of
/// `submit(_:)` must end the save.
@MainActor
@Observable
final class TaskCompletionSubmission {
    private(set) var isSaving = false
    var isShowingFailure = false
    private(set) var failureMessage = ""

    /// Runs `save` unless a save is already running.
    ///
    /// `save` throws only when nothing was saved. A `CancellationError` ends the save without an
    /// alert; the sheet stays open, so the user can tap Complete again.
    ///
    /// - Returns: `true` when `save` finished without an error.
    @discardableResult
    func submit(_ save: @MainActor () async throws -> Void) async -> Bool {
        // The check and the flag change run with no suspension point between them, so a second tap
        // cannot start a second save.
        guard isSaving == false else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            try await save()
            return true
        } catch is CancellationError {
            return false
        } catch {
            failureMessage = Self.message(for: error)
            isShowingFailure = true
            return false
        }
    }

    /// The app's own errors carry a sentence written for people. A raw system error, such as a
    /// SwiftData save error, does not, so the alert shows a fixed sentence instead.
    private static func message(for error: any Error) -> String {
        if !(error is CocoaError),
           let description = (error as? any LocalizedError)?.errorDescription,
           description.isEmpty == false {
            return description
        }
        return String(localized: .errorDataSaveMessage)
    }
}
