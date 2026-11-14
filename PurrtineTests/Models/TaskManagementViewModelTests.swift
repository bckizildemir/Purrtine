import Foundation
import SwiftData
import Testing
import UIKit
@testable import Purrtine

@MainActor
struct TaskManagementViewModelTests {
    @Test
    func multiCatCompletionPresentsDetailedSheetInsteadOfCompletingInline() {
        let sut = TaskManagementViewModel()
        let completedForDate = Date(timeIntervalSince1970: 1_710_000_000)
        let task = CareTask(title: "Feed Everyone")
        task.assignedCats = [Cat(name: "Mochi"), Cat(name: "Luna")]

        let completedInline = sut.handleCompletionAction(for: task, completedForDate: completedForDate)

        #expect(completedInline == nil)
        #expect(sut.taskCompletionRequest?.task.id == task.id)
        #expect(sut.taskCompletionRequest?.completedForDate == completedForDate)
        #expect(task.completions.isEmpty)
    }

    @Test
    func routedTaskNavigationReturnsToListAndSelectsMatchingTask() {
        let sut = TaskManagementViewModel()
        let targetTask = CareTask(title: "Brush Mochi")
        let otherTask = CareTask(title: "Clean Fountain")
        sut.selectedViewMode = .calendar

        sut.handleTaskNavigation(taskId: targetTask.id, from: [otherTask, targetTask])

        #expect(sut.selectedViewMode == .list)
        #expect(sut.selectedCareTask?.id == targetTask.id)
    }

    @Test
    func presentationStateCanBePresentedAndDismissed() {
        let sut = TaskManagementViewModel()
        let task = CareTask(title: "Brush")
        let date = Date(timeIntervalSince1970: 1_710_000_000)

        sut.presentTaskTemplateSelection()
        #expect(sut.showingTaskTemplate)
        sut.dismissTaskTemplateSelection()
        #expect(sut.showingTaskTemplate == false)

        sut.presentTaskCreation()
        #expect(sut.taskCreationRequest != nil)
        sut.dismissTaskCreation()
        #expect(sut.taskCreationRequest == nil)

        sut.presentTaskEdit(task)
        #expect(sut.selectedCareTask?.id == task.id)
        sut.dismissTaskEdit()
        #expect(sut.selectedCareTask == nil)

        sut.presentTaskCompletion(task, completedForDate: date)
        #expect(sut.taskCompletionRequest?.completedForDate == date)
        sut.dismissTaskCompletion()
        #expect(sut.taskCompletionRequest == nil)
    }

    @Test(arguments: [
        (rawValue: CareTaskViewMode.list.rawValue, expected: CareTaskViewMode.list),
        (rawValue: CareTaskViewMode.calendar.rawValue, expected: CareTaskViewMode.calendar),
        (rawValue: "unsupported", expected: CareTaskViewMode.list)
    ])
    func defaultTaskViewPreferenceFallsBackToList(
        rawValue: String,
        expected: CareTaskViewMode
    ) {
        #expect(TaskViewPreference.resolvedViewMode(from: rawValue) == expected)
    }

    @Test
    func missingDefaultTaskViewPreferenceFallsBackToList() {
        #expect(TaskViewPreference.resolvedViewMode(from: nil) == .list)
    }

    @Test
    func awaitedCompletionHandsTheTaskAndItsDetailsToTheWriter() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let spy = CareTaskWriterSpy()
        let caregiver = Caregiver(name: "Primary", role: .primary)
        let task = CareTask(title: "Feed")
        let schedule = CareTaskSchedule(scheduledDate: Date(), frequency: .once)
        schedule.task = task
        task.schedules = [schedule]
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: context, tasks: [task])

        try await sut.completeCareTaskAndWait(task, by: caregiver, with: "Done")

        let completion = try #require(spy.completions.first)
        #expect(spy.completions.count == 1)
        #expect(completion.task === task)
        #expect(completion.input.caregiver === caregiver)
        #expect(completion.input.notes == "Done")
    }

    @Test
    func failedSheetCompletionKeepsTheSheetOpenAndRecordsNothing() async throws {
        let fixture = try makeCompletionFixture()
        let sut = TaskManagementViewModel(taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()))
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)

        // No caregiver exists and none is chosen, so the completion cannot be recorded.
        await #expect(throws: TaskActionError.caregiverUnavailable) {
            try await sut.submitCompletion(of: fixture.task, by: nil, with: "Done")
        }

        #expect(sut.taskCompletionRequest?.task === fixture.task)
        #expect(fixture.task.completions.isEmpty)
    }

    /// The completion committed, so the sheet must close; offering a retry would record it twice.
    @Test
    func sheetCompletionWithStaleRemindersClosesTheSheet() async throws {
        let fixture = try makeCompletionFixture()
        let caregiver = Caregiver(name: "Primary", role: .primary)
        fixture.context.insert(caregiver)
        try fixture.context.save()
        let scheduler = NotificationSchedulerSpy()
        scheduler.resyncError = .forcedFailure
        let sut = TaskManagementViewModel(taskWriter: CareTaskWriter(scheduler: scheduler))
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)

        try await sut.submitCompletion(of: fixture.task, by: caregiver)

        #expect(sut.taskCompletionRequest == nil)
        #expect(fixture.task.completions.count == 1)
    }

    /// The warning waits for the sheet to close: an alert raised while the sheet is still on screen
    /// cannot be presented from the view underneath it.
    @Test
    func sheetCompletionWithStaleRemindersWarnsOnceTheSheetHasClosed() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)

        try await sut.submitCompletion(of: fixture.task, by: nil)

        #expect(sut.taskCompletionRequest == nil)
        #expect(spy.completions.count == 1)
        #expect(sut.isShowingReminderWarning == false)

        sut.sheetDidDismiss(.taskCompletion)

        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func oneTapCompletionWithStaleRemindersCountsAsDoneAndWarns() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(spy.completions.count == 1)
        #expect(sut.taskCompletionRequest == nil)
        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func cancelledOneTapCompletionShowsNoWarning() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = CancellationError()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(spy.completions.count == 1)
        #expect(sut.isShowingReminderWarning == false)
        #expect(sut.actionFailure == nil)
        #expect(sut.isShowingActionFailure == false)
    }

    /// "Not saved" is a different failure; a reminder warning would tell the caregiver it was done.
    @Test
    func unsavedOneTapCompletionShowsTheNotSavedMessage() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = TaskActionError.caregiverUnavailable
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(sut.actionFailure == .completionNotSaved)
        #expect(sut.isShowingActionFailure)
        #expect(sut.isShowingReminderWarning == false)
    }

    @Test
    func cancelledSheetCompletionStillClosesTheSheet() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = CancellationError()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)

        try await sut.submitCompletion(of: fixture.task, by: nil)
        sut.sheetDidDismiss(.taskCompletion)

        #expect(sut.taskCompletionRequest == nil)
        #expect(spy.completions.count == 1)
        #expect(sut.isShowingReminderWarning == false)
    }

    @Test
    func sheetCompletionWithoutAStoreKeepsTheSheetOpen() async throws {
        let spy = CareTaskWriterSpy()
        let sut = TaskManagementViewModel(taskWriter: spy)
        let task = CareTask(title: "Feed")
        sut.presentTaskCompletion(task, completedForDate: nil)

        await #expect(throws: (any Error).self) {
            try await sut.submitCompletion(of: task, by: nil)
        }

        #expect(sut.taskCompletionRequest?.task === task)
        #expect(spy.completions.isEmpty)
    }

    @Test
    func blockedPhotoFolderThrowsATypedErrorLogsItAndCommitsNothing() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder(blocked: true)
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)

        await #expect(throws: PhotoSaveError.self) {
            try await sut.submitCompletion(of: fixture.task, by: nil, photos: [try CareTaskPhotoFolder.makeImage()])
        }

        #expect(folder.log.messages.count == 1)
        #expect(spy.completions.isEmpty)
        #expect(sut.taskCompletionRequest?.task === fixture.task)
    }

    /// The sheet asks the caregiver what to do, instead of the general "not saved" alert.
    @Test
    func blockedPhotoFolderShowsThePhotoAlertOnTheSheet() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder(blocked: true)
        defer { folder.remove() }
        let sut = TaskManagementViewModel(taskWriter: CareTaskWriterSpy(), photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)
        let submission = TaskCompletionSubmission()
        let photo = try CareTaskPhotoFolder.makeImage()

        let didSave = await submission.submit {
            try await sut.submitCompletion(of: fixture.task, by: nil, photos: [photo])
        }

        #expect(didSave == false)
        #expect(submission.isShowingPhotoNotSaved)
        #expect(submission.isShowingFailure == false)
        #expect(sut.taskCompletionRequest?.task === fixture.task)
    }

    /// Nothing is committed, so the photos that did save would belong to no completion.
    @Test
    func anUnsavedPhotoRemovesThePhotosThatDidSave() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let photos = [UIImage(), try CareTaskPhotoFolder.makeImage()]

        await #expect(throws: PhotoSaveError.self) {
            try await sut.submitCompletion(of: fixture.task, by: nil, photos: photos)
        }

        #expect(spy.completions.isEmpty)
        #expect(try folder.storedFileNames().isEmpty)
    }

    @Test
    func failedCompletionCommitLeavesNoNewPhotoFile() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        spy.completeError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let photo = try CareTaskPhotoFolder.makeImage()

        await #expect(throws: CocoaError.self) {
            try await sut.submitCompletion(of: fixture.task, by: nil, photos: [photo])
        }

        let completion = try #require(spy.completions.first)
        #expect(completion.input.photoURLs.count == 1)
        #expect(try folder.storedFileNames().isEmpty)
    }

    /// A completion with stale reminders committed, so it keeps its photos.
    @Test
    func completionWithStaleRemindersKeepsItsPhotoFiles() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)
        let photo = try CareTaskPhotoFolder.makeImage()

        try await sut.submitCompletion(of: fixture.task, by: nil, photos: [photo])

        let completion = try #require(spy.completions.first)
        #expect(try folder.storedFileNames() == Set(completion.input.photoURLs))
        #expect(completion.input.photoURLs.count == 1)
    }

    /// A completion cancelled after its commit stands, so it keeps its photos.
    @Test
    func cancelledCompletionKeepsItsPhotoFiles() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        spy.completeError = CancellationError()
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)
        let photo = try CareTaskPhotoFolder.makeImage()

        try await sut.submitCompletion(of: fixture.task, by: nil, photos: [photo])

        let completion = try #require(spy.completions.first)
        #expect(try folder.storedFileNames() == Set(completion.input.photoURLs))
        #expect(completion.input.photoURLs.count == 1)
    }

    @Test
    func completeWithoutPhotoCommitsTheCompletionWithoutTheFailedPhoto() async throws {
        let fixture = try makeCompletionFixture()
        let caregiver = Caregiver(name: "Primary", role: .primary)
        fixture.context.insert(caregiver)
        try fixture.context.save()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let sut = TaskManagementViewModel(
            taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()),
            photoWriter: folder.sut
        )
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)
        let photos = [UIImage(), try CareTaskPhotoFolder.makeImage()]

        try await sut.submitCompletion(
            of: fixture.task,
            by: caregiver,
            photos: photos,
            unsavedPhotos: .completeWithout
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(fixture.task.completions.count == 1)
        #expect(completion.photoURLs.count == 1)
        #expect(try folder.storedFileNames() == Set(completion.photoURLs))
        #expect(sut.taskCompletionRequest == nil)
    }

    @Test
    func completeWithoutPhotoInABlockedFolderCommitsWithNoPhotos() async throws {
        let fixture = try makeCompletionFixture()
        let folder = try CareTaskPhotoFolder(blocked: true)
        defer { folder.remove() }
        let spy = CareTaskWriterSpy()
        let sut = TaskManagementViewModel(taskWriter: spy, photoWriter: folder.sut)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let photo = try CareTaskPhotoFolder.makeImage()

        try await sut.submitCompletion(of: fixture.task, by: nil, photos: [photo], unsavedPhotos: .completeWithout)

        let completion = try #require(spy.completions.first)
        #expect(spy.completions.count == 1)
        #expect(completion.input.photoURLs.isEmpty)
    }

    @Test
    func awaitedDeletionHandsTheTaskToTheWriterAndDropsItFromTheList() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let spy = CareTaskWriterSpy()
        let task = CareTask(title: "Delete me")
        context.insert(task)
        try context.save()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: context, tasks: [task])

        try await sut.deleteCareTaskAndWait(task)

        #expect(spy.deletedTaskIds == [task.id])
        #expect(sut.groupedTasks.isEmpty)
    }

    /// A failed delete commit stays staged and lands on the next save, so the row stays removed and
    /// the message says the delete will finish later, never that the task was not deleted.
    @Test
    func failedDeleteCommitKeepsTheRowRemovedAndSaysTheDeleteIsPending() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.deleteCareTask(fixture.task).value

        #expect(spy.deletedTaskIds == [fixture.task.id])
        #expect(sut.groupedTasks.isEmpty)
        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
        #expect(sut.isShowingReminderWarning == false)
    }

    @Test
    func deleteWithStaleRemindersStandsAndWarnsAboutReminders() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.deleteError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.deleteCareTask(fixture.task).value

        #expect(sut.groupedTasks.isEmpty)
        #expect(sut.isShowingReminderWarning)
        #expect(sut.actionFailure == nil)
        #expect(sut.isShowingActionFailure == false)
    }

    @Test
    func cancelledDeleteShowsNoMessage() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.deleteError = CancellationError()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.deleteCareTask(fixture.task).value

        #expect(sut.groupedTasks.isEmpty)
        #expect(sut.isShowingReminderWarning == false)
        #expect(sut.actionFailure == nil)
        #expect(sut.isShowingActionFailure == false)
    }

    // MARK: - Alerts wait for an open sheet

    /// An alert raised under an open sheet cannot present, so it waits for the sheet to close.
    @Test
    func oneTapCompletionWithStaleRemindersWarnsOnceAnOpenSheetHasClosed() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskEdit(fixture.task)

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(spy.completions.count == 1)
        #expect(sut.isShowingReminderWarning == false)

        sut.dismissTaskEdit()
        sut.sheetDidDismiss(.taskEdit)

        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func unsavedOneTapCompletionShowsTheFailureOnceAnOpenSheetHasClosed() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = TaskActionError.caregiverUnavailable
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskTemplateSelection()

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(sut.isShowingActionFailure == false)

        sut.dismissTaskTemplateSelection()
        sut.sheetDidDismiss(.taskTemplate)

        #expect(sut.actionFailure == .completionNotSaved)
        #expect(sut.isShowingActionFailure)
    }

    /// The add-cat sheet is the view's own state, so the view reports it.
    @Test
    func failedDeleteShowsTheFailureOnceTheAddCatSheetHasClosed() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.addCatSheetWillPresent()

        await sut.deleteCareTask(fixture.task).value

        #expect(sut.isShowingActionFailure == false)

        sut.sheetDidDismiss(.addCat)

        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
    }

    /// The sheet's state is cleared before it animates away; the alert waits for the dismiss callback.
    @Test
    func anAlertWaitsWhileAClosingSheetIsStillOnScreen() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.deleteError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskCreation()
        sut.dismissTaskCreation()

        await sut.deleteCareTask(fixture.task).value

        #expect(sut.isShowingReminderWarning == false)

        sut.sheetDidDismiss(.taskCreation)

        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func anAlertWaitsUntilEverySheetHasClosed() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskTemplateSelection()
        sut.presentTaskCreation()

        await sut.completeCareTask(fixture.task, by: nil).value
        sut.dismissTaskTemplateSelection()
        sut.sheetDidDismiss(.taskTemplate)

        #expect(sut.isShowingReminderWarning == false)

        sut.dismissTaskCreation()
        sut.sheetDidDismiss(.taskCreation)

        #expect(sut.isShowingReminderWarning)
    }

    /// A sheet whose state was replaced, not cleared, is still on screen after the old one closes.
    @Test
    func aDismissCallbackForAReplacedSheetKeepsTheAlertWaiting() async throws {
        let fixture = try makeCompletionFixture()
        let otherTask = CareTask(title: "Brush")
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskEdit(fixture.task)

        await sut.completeCareTask(fixture.task, by: nil).value
        sut.presentTaskEdit(otherTask)
        sut.sheetDidDismiss(.taskEdit)

        #expect(sut.isShowingReminderWarning == false)

        sut.dismissTaskEdit()
        sut.sheetDidDismiss(.taskEdit)

        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func twoPendingAlertsShowOneAfterTheOtherActionFailureFirst() async throws {
        let fixture = try makeCompletionFixture()
        let otherTask = CareTask(title: "Brush")
        fixture.context.insert(otherTask)
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task, otherTask])
        sut.presentTaskEdit(fixture.task)

        await sut.completeCareTask(fixture.task, by: nil).value
        await sut.deleteCareTask(otherTask).value
        sut.dismissTaskEdit()
        sut.sheetDidDismiss(.taskEdit)

        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
        #expect(sut.isShowingReminderWarning == false)

        // The caregiver closes the first alert.
        sut.isShowingActionFailure = false
        await sut.nextAlertPresentation?.value

        #expect(sut.isShowingReminderWarning)
    }

    @Test
    func twoPendingActionFailuresBothShowInTheOrderTheyHappened() async throws {
        let fixture = try makeCompletionFixture()
        let otherTask = CareTask(title: "Brush")
        fixture.context.insert(otherTask)
        let spy = CareTaskWriterSpy()
        spy.completeError = TaskActionError.caregiverUnavailable
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task, otherTask])
        sut.presentTaskEdit(fixture.task)

        await sut.completeCareTask(fixture.task, by: nil).value
        await sut.deleteCareTask(otherTask).value
        sut.dismissTaskEdit()
        sut.sheetDidDismiss(.taskEdit)

        #expect(sut.actionFailure == .completionNotSaved)
        #expect(sut.isShowingActionFailure)

        sut.isShowingActionFailure = false
        await sut.nextAlertPresentation?.value

        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
    }

    /// Setting the same alert's flag back to `true` inside the write that closes it is no change to
    /// SwiftUI, so that alert would never present and its flag would block every later alert.
    @Test
    func theNextAlertWaitsUntilTheClosingAlertsWriteHasFinished() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = TaskActionError.caregiverUnavailable
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        await sut.completeCareTask(fixture.task, by: nil).value
        await sut.deleteCareTask(fixture.task).value
        #expect(sut.actionFailure == .completionNotSaved)

        sut.isShowingActionFailure = false

        #expect(sut.isShowingActionFailure == false)

        await sut.nextAlertPresentation?.value

        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
    }

    /// Without a sheet, an alert raised while another alert is up waits for that alert to close.
    @Test
    func anAlertRaisedWhileAnotherIsUpShowsAfterItCloses() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        spy.deleteError = CocoaError(.fileWriteUnknown)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.completeCareTask(fixture.task, by: nil).value
        #expect(sut.isShowingReminderWarning)

        await sut.deleteCareTask(fixture.task).value
        #expect(sut.isShowingActionFailure == false)

        sut.isShowingReminderWarning = false
        await sut.nextAlertPresentation?.value

        #expect(sut.actionFailure == .deletePending)
        #expect(sut.isShowingActionFailure)
    }

    /// A shown alert leaves nothing behind: the next one presents at once.
    @Test
    func aShownPendingAlertDoesNotBlockLaterAlerts() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = makeRemindersOutOfSyncError(for: fixture.task)
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        sut.presentTaskEdit(fixture.task)
        await sut.completeCareTask(fixture.task, by: nil).value
        sut.dismissTaskEdit()
        sut.sheetDidDismiss(.taskEdit)
        #expect(sut.isShowingReminderWarning)
        sut.isShowingReminderWarning = false

        await sut.completeCareTask(fixture.task, by: nil).value

        #expect(sut.isShowingReminderWarning)
    }

    /// The sheet opened while today was due, and the task was completed elsewhere (a reminder, the
    /// list) before Complete was tapped. Tomorrow is due now and must not be completed.
    @Test
    func sheetSubmitAfterTheTaskWasCompletedElsewhereRecordsNothingAndShowsTheError() async throws {
        let fixture = try makeRecurringFixture()
        let sut = TaskManagementViewModel(taskWriter: fixture.writer)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let today = Calendar.current.startOfDay(for: fixture.schedule.scheduledDate)
        sut.presentTaskCompletion(fixture.task, completedForDate: nil)
        let request = try #require(sut.taskCompletionRequest)
        #expect(request.expectedOccurrence == today)
        try await fixture.writer.complete(fixture.task, with: CareTaskCompletionInput(), in: fixture.context)
        let tomorrowsSchedule = try #require(fixture.task.activeSchedule)

        let submission = TaskCompletionSubmission()
        await submission.submit {
            try await sut.submitCompletion(
                of: request.task,
                by: nil,
                completedForDate: request.completedForDate,
                expectedOccurrence: request.expectedOccurrence
            )
        }

        #expect(fixture.task.completions.count == 1)
        #expect(fixture.task.activeSchedule?.id == tomorrowsSchedule.id)
        #expect(submission.isShowingFailure)
        #expect(submission.failureMessage == TaskActionError.occurrenceNotOpen.localizedDescription)
        #expect(sut.taskCompletionRequest != nil)
    }

    /// Calendar path with a one-tap row: a later selected day is refused, and the refusal shows.
    @Test
    func completingALaterSelectedDayRecordsNothingAndShowsTheRefusal() async throws {
        let fixture = try makeRecurringFixture()
        let sut = TaskManagementViewModel(taskWriter: fixture.writer)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))

        await sut.completeCareTask(fixture.task, by: nil, completedForDate: tomorrow).value

        #expect(fixture.task.completions.isEmpty)
        #expect(fixture.task.activeSchedule?.id == fixture.schedule.id)
        #expect(sut.actionFailure == .occurrenceNotOpen)
        #expect(sut.isShowingActionFailure)
        #expect(sut.isShowingReminderWarning == false)
    }

    /// The row passes the day that was due at the tap, so the writer can refuse a stale one.
    @Test
    func rowCompletionPassesTheOpenOccurrenceAtTapTime() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let expected = Calendar.current.startOfDay(for: try #require(fixture.task.activeSchedule).scheduledDate)

        await sut.handleCompletionAction(for: fixture.task)?.value

        #expect(spy.completions.first?.input.expectedOccurrence == expected)
    }

    /// Calendar path, two cats: a later selected day is refused before the sheet opens, with the alert
    /// the one-tap path shows, not after the caregiver filled the sheet in.
    @Test
    func aLaterCalendarDayForAMultiCatTaskIsRefusedBeforeTheSheetOpens() async throws {
        let fixture = try makeRecurringFixture()
        fixture.task.assignedCats = [Cat(name: "Mochi"), Cat(name: "Luna")]
        let sut = TaskManagementViewModel(taskWriter: fixture.writer)
        sut.configure(with: fixture.context, tasks: [fixture.task])
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))

        sut.handleCalendarCompletion(of: fixture.task, on: tomorrow)

        #expect(sut.taskCompletionRequest == nil)
        #expect(sut.actionFailure == .occurrenceNotOpen)
        #expect(sut.isShowingActionFailure)
        #expect(fixture.task.completions.isEmpty)
    }

    @Test
    func theOpenCalendarDayForAMultiCatTaskOpensTheSheet() throws {
        let fixture = try makeRecurringFixture()
        fixture.task.assignedCats = [Cat(name: "Mochi"), Cat(name: "Luna")]
        let sut = TaskManagementViewModel(taskWriter: fixture.writer)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        sut.handleCalendarCompletion(of: fixture.task, on: fixture.schedule.scheduledDate)

        #expect(sut.taskCompletionRequest?.task === fixture.task)
        #expect(sut.actionFailure == nil)
    }

    private func makeRecurringFixture() throws -> (
        container: ModelContainer,
        context: ModelContext,
        task: CareTask,
        schedule: CareTaskSchedule,
        writer: CareTaskWriter
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        let task = CareTask(title: "Feed Luna", category: .feeding)
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            frequency: .daily,
            frequencyInterval: 1
        )
        schedule.task = task
        task.schedules = [schedule]
        task.assignedCaregiver = caregiver
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()
        return (container, context, task, schedule, CareTaskWriter(scheduler: NotificationSchedulerSpy()))
    }

    private func makeRemindersOutOfSyncError(for task: CareTask) -> CareTaskRemindersOutOfSyncError {
        CareTaskRemindersOutOfSyncError(taskIds: [task.id], underlyingError: CocoaError(.featureUnsupported))
    }

    private func makeCompletionFixture() throws -> (container: ModelContainer, context: ModelContext, task: CareTask) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let task = CareTask(title: "Feed")
        let schedule = CareTaskSchedule(scheduledDate: Date(), frequency: .once)
        schedule.task = task
        task.schedules = [schedule]
        context.insert(task)
        context.insert(schedule)
        try context.save()
        return (container, context, task)
    }
}
