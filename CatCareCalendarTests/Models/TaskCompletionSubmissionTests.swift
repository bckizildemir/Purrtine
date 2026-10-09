import Foundation
import Testing
@testable import CatCareCalendar

@MainActor
struct TaskCompletionSubmissionTests {
    @Test
    func successfulSaveEndsSavingWithoutAnAlert() async {
        let sut = TaskCompletionSubmission()

        let didSave = await sut.submit {}

        #expect(didSave)
        #expect(sut.isSaving == false)
        #expect(sut.isShowingFailure == false)
    }

    @Test
    func failedSaveEndsSavingAndShowsTheErrorDescription() async {
        let sut = TaskCompletionSubmission()

        let didSave = await sut.submit { throw TaskActionError.caregiverUnavailable }

        #expect(didSave == false)
        #expect(sut.isSaving == false)
        #expect(sut.isShowingFailure)
        #expect(sut.failureMessage == TaskActionError.caregiverUnavailable.errorDescription)
    }

    /// A raw system error has no sentence written for people, so the alert shows a fixed one.
    @Test(arguments: [
        NSError(domain: NSCocoaErrorDomain, code: 1570),
        CocoaError(.validationMissingMandatoryProperty) as NSError,
        TaskManagementViewModel.StoreUnavailableError() as NSError
    ])
    func rawSystemErrorShowsTheFixedSentence(error: NSError) async {
        let sut = TaskCompletionSubmission()

        await sut.submit { throw error }

        #expect(sut.isShowingFailure)
        #expect(sut.failureMessage == String(localized: .errorDataSaveMessage))
    }

    @Test
    func cancelledSaveEndsSavingWithoutAnAlert() async {
        let sut = TaskCompletionSubmission()

        let didSave = await sut.submit { throw CancellationError() }

        #expect(didSave == false)
        #expect(sut.isSaving == false)
        #expect(sut.isShowingFailure == false)
    }

    @Test
    func secondSubmitWhileSavingIsIgnored() async {
        let sut = TaskCompletionSubmission()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
        var saveCount = 0

        let first = Task {
            await sut.submit {
                saveCount += 1
                startedContinuation.yield()
                for await _ in release {}
            }
        }
        for await _ in started { break }

        #expect(sut.isSaving)
        let secondDidSave = await sut.submit { saveCount += 1 }
        releaseContinuation.finish()
        let firstDidSave = await first.value

        #expect(secondDidSave == false)
        #expect(firstDidSave)
        #expect(saveCount == 1)
        #expect(sut.isSaving == false)
    }
}
