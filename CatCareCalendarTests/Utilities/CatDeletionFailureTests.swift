import Foundation
import Testing
@testable import CatCareCalendar

@MainActor
struct CatDeletionFailureTests {
    @Test
    func cancellationIsNotAFailureToReport() {
        #expect(CatDeletionFailure(error: CancellationError(), catName: "Mochi") == nil)
    }

    @Test
    func remindersOutOfSyncMeansDeletedWithStaleReminders() {
        let error = CareTaskRemindersOutOfSyncError(taskIds: [UUID()], underlyingError: SomeFailure())

        #expect(CatDeletionFailure(error: error, catName: "Mochi") == .remindersStale(catName: "Mochi"))
    }

    /// Any other error came from the commit, which leaves the delete staged for the next save.
    @Test
    func anyOtherErrorMeansTheDeleteIsStillPending() {
        #expect(CatDeletionFailure(error: SomeFailure(), catName: "Mochi") == .commitPending(catName: "Mochi"))
    }

    @Test(arguments: [
        CatDeletionFailure.remindersStale(catName: "Mochi"),
        CatDeletionFailure.commitPending(catName: "Mochi"),
    ])
    func messageNamesTheCat(failure: CatDeletionFailure) {
        #expect(failure.title.isEmpty == false)
        #expect(failure.message.contains("Mochi"))
    }
}

private struct SomeFailure: Error {}
