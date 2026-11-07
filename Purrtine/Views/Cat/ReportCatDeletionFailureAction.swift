import SwiftUI

/// Hands a failed cat delete to the screen that shows its alert.
///
/// The screens that delete a cat — Edit Cat, opened from a cat card or from the cat detail, and the
/// cat card's own menu — leave the screen with the cat: the card and the detail's link drop out of
/// the `@Query` list, and the sheets they present go with them. So none of them can host the alert.
/// `CatsTabView`, which they all sit under, sets this action and shows the alert. The default does
/// nothing, for a view outside that hierarchy such as a preview; `CatDeletionService` has already
/// logged the failure.
struct ReportCatDeletionFailureAction {
    private let report: @MainActor (CatDeletionFailure) -> Void

    /// `nonisolated` so the `@Entry` environment default below, which is read outside the main
    /// actor, can build one.
    nonisolated init(_ report: @escaping @MainActor (CatDeletionFailure) -> Void) {
        self.report = report
    }

    func callAsFunction(_ failure: CatDeletionFailure) {
        report(failure)
    }
}

extension EnvironmentValues {
    @Entry var reportCatDeletionFailure = ReportCatDeletionFailureAction { _ in }
}
