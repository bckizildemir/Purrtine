/// Holds a failed cat delete until the screen that deleted the cat has left, then hands it to
/// `CatsTabView` once (#31).
///
/// UIKit refuses to present the cats screen's alert while the deleting screen is still on screen,
/// so the failure waits for `onDisappear`. But that screen can also leave first: the cat leaves the
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

    private func reportIfReady() {
        guard isScreenUp == false, let pending else { return }
        self.pending = nil
        pending.report(pending.failure)
    }
}
