import Foundation
import Testing
@testable import CatCareCalendar

struct CareTaskWriteFailureTests {
    @Test
    func cancellationSortsAsCancelled() {
        let failure = CareTaskWriteFailure(CancellationError())

        #expect(failure.isCancelled)
    }

    @Test
    func outOfSyncErrorSortsAsSavedWithStaleReminders() throws {
        let taskId = UUID()
        let error = CareTaskRemindersOutOfSyncError(
            taskIds: [taskId],
            underlyingError: CocoaError(.featureUnsupported)
        )

        let failure = CareTaskWriteFailure(error)

        guard case .remindersStale(let staleError) = failure else {
            Issue.record("Expected .remindersStale, got \(failure)")
            return
        }
        #expect(staleError.taskIds == [taskId])
    }

    @Test(arguments: [
        TaskActionError.caregiverUnavailable as any Error,
        CocoaError(.validationMissingMandatoryProperty),
        NSError(domain: NSCocoaErrorDomain, code: 1570)
    ])
    func anyOtherErrorSortsAsNotSaved(error: any Error) {
        let failure = CareTaskWriteFailure(error)

        guard case .notSaved(let underlyingError) = failure else {
            Issue.record("Expected .notSaved, got \(failure)")
            return
        }
        #expect((underlyingError as NSError) == (error as NSError))
    }
}

private extension CareTaskWriteFailure {
    var isCancelled: Bool {
        if case .cancelled = self { true } else { false }
    }
}
