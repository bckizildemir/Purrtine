/// Holds a failed cat delete until the screen that deleted the cat has left, then hands it to
/// `CatsTabView` once (#31).
///
/// UIKit refuses to present the cats screen's alert while the deleting screen, or a confirmation it
/// presented, is still on screen, so the failure waits for `onDisappear`. On the cat card that is the
/// card leaving the grid with the cat, which also takes its confirmation alert. A commit failure
/// throws before the delete's first suspension, so without this hold the card would report it while
/// that confirmation may still be closing. The screen can also leave first: the cat leaves the
/// `@Query` list the moment it is deleted, which takes a cat card, and the Edit Cat sheet it
/// presents, with it before the delete has finished its reminder refresh. A failure that finishes
/// after the screen has left is reported at once.
///
/// A reference type, so the delete's `Task` keeps the same instance after the view is gone: read
/// it into a local before the `Task` starts, because a view's `@State` read after the view has left
/// is not this instance.
@MainActor
final class CatDeletionFailureHandoff {
    private var isScreenUp = false
    private var pending: (failure: CatDeletionFailure, report: ReportCatDeletionFailureAction)?

    /// Call from `onAppear`.
    func screenDidAppear() {
        isScreenUp = true
    }

    /// Call from `onDisappear`.
    func screenDidLeave() {
        isScreenUp = false
        reportIfReady()
    }

    /// Call when the delete has finished. `nil` — a success or a cancellation — reports nothing.
    func deleteDidFinish(with failure: CatDeletionFailure?, reporting report: ReportCatDeletionFailureAction) {
        pending = failure.map { ($0, report) }
        reportIfReady()
    }

    /// Runs `delete`, sorts what it throws, and hands a failure on as `deleteDidFinish` does.
    /// Returns the failure, so the caller can play the matching haptic.
    @discardableResult
    func runDelete(
        ofCatNamed catName: String,
        reporting report: ReportCatDeletionFailureAction,
        _ delete: () async throws -> Void
    ) async -> CatDeletionFailure? {
        var failure: CatDeletionFailure?
        do {
            try await delete()
        } catch {
            failure = CatDeletionFailure(error: error, catName: catName)
        }
        deleteDidFinish(with: failure, reporting: report)
        return failure
    }

    private func reportIfReady() {
        guard isScreenUp == false, let pending else { return }
        self.pending = nil
        pending.report(pending.failure)
    }
}
