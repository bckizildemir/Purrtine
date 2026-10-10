import Testing
@testable import CatCareCalendar

/// The deleting screen hands its failure to `CatsTabView` only once it has left, whichever comes
/// first: the screen leaving or the delete finishing (#31).
@MainActor
struct CatDeletionFailureHandoffTests {
    private let failure = CatDeletionFailure.remindersStale(catName: "Mochi")

    @Test
    func aFailureThatFinishesWhileTheScreenIsUpWaitsUntilItLeaves() {
        var reported: [CatDeletionFailure] = []
        let sut = CatDeletionFailureHandoff()
        sut.screenDidAppear()

        sut.deleteDidFinish(with: failure, reporting: ReportCatDeletionFailureAction { reported.append($0) })
        #expect(reported.isEmpty)

        sut.screenDidLeave()
        #expect(reported == [failure])
    }

    /// Edit Cat opened from a cat card: the card leaves the grid with the cat, its sheet closes,
    /// and the form leaves before the reminder refresh has failed.
    @Test(.bug("https://github.com/bckizildemir/Purrtine/issues/31", id: 31))
    func aFailureThatFinishesAfterTheScreenLeftIsReportedAtOnce() {
        var reported: [CatDeletionFailure] = []
        let sut = CatDeletionFailureHandoff()
        sut.screenDidAppear()
        sut.screenDidLeave()

        sut.deleteDidFinish(with: failure, reporting: ReportCatDeletionFailureAction { reported.append($0) })

        #expect(reported == [failure])
    }

    @Test
    func aFailureIsReportedOnlyOnce() {
        var reported: [CatDeletionFailure] = []
        let sut = CatDeletionFailureHandoff()
        sut.screenDidAppear()
        sut.deleteDidFinish(with: failure, reporting: ReportCatDeletionFailureAction { reported.append($0) })

        sut.screenDidLeave()
        sut.screenDidAppear()
        sut.screenDidLeave()

        #expect(reported == [failure])
    }

    /// A screen that comes back, such as one uncovered by a closing full-screen cover, holds the
    /// failure again until it really leaves.
    @Test
    func aScreenThatAppearsAgainHoldsTheFailureUntilItLeaves() {
        var reported: [CatDeletionFailure] = []
        let sut = CatDeletionFailureHandoff()
        sut.screenDidAppear()
        sut.screenDidLeave()
        sut.screenDidAppear()

        sut.deleteDidFinish(with: failure, reporting: ReportCatDeletionFailureAction { reported.append($0) })
        #expect(reported.isEmpty)

        sut.screenDidLeave()
        #expect(reported == [failure])
    }

    /// A delete that succeeded, or was cancelled, has nothing to report.
    @Test
    func noFailureReportsNothing() {
        var reported: [CatDeletionFailure] = []
        let sut = CatDeletionFailureHandoff()
        sut.screenDidAppear()

        sut.deleteDidFinish(with: nil, reporting: ReportCatDeletionFailureAction { reported.append($0) })
        sut.screenDidLeave()

        #expect(reported.isEmpty)
    }
}
