import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct TaskManagementViewModelTests {
    @Test
    func multiCatCompletionPresentsDetailedSheetInsteadOfCompletingInline() {
        let sut = TaskManagementViewModel()
        let completedForDate = Date(timeIntervalSince1970: 1_710_000_000)
        let task = CareTask(title: "Feed Everyone")
        task.assignedCats = [Cat(name: "Mochi"), Cat(name: "Luna")]

        let completedInline = sut.handleCompletionAction(for: task, completedForDate: completedForDate)

        #expect(completedInline == false)
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

        sut.taskCompletionSheetDidDismiss()

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
    }

    /// "Not saved" is a different failure; a reminder warning would tell the caregiver it was done.
    @Test
    func unsavedOneTapCompletionShowsNoReminderWarning() async throws {
        let fixture = try makeCompletionFixture()
        let spy = CareTaskWriterSpy()
        spy.completeError = TaskActionError.caregiverUnavailable
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: fixture.context, tasks: [fixture.task])

        await sut.completeCareTask(fixture.task, by: nil).value

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
        sut.taskCompletionSheetDidDismiss()

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

    @Test
    func awaitedDuplicationCopiesOnlyActiveSchedulesAndOffsetsRange() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let spy = CareTaskWriterSpy()
        let task = CareTask(title: "Medication")
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let end = start.addingTimeInterval(7 * 24 * 60 * 60)
        let active = CareTaskSchedule(
            scheduledDate: start,
            frequency: .weekly,
            endDate: end,
            reminderMinutes: 15
        )
        let inactive = CareTaskSchedule(scheduledDate: start, frequency: .daily)
        active.task = task
        inactive.task = task
        inactive.isActive = false
        task.schedules = [active, inactive]
        context.insert(task)
        context.insert(active)
        context.insert(inactive)
        try context.save()
        let sut = TaskManagementViewModel(taskWriter: spy)
        sut.configure(with: context, tasks: [task])

        let duplicate = try #require(try await sut.duplicateTaskAndWait(task))
        let duplicateSchedule = try #require(duplicate.activeSchedule)
        let expectedStart = try #require(Calendar.current.date(byAdding: .day, value: 1, to: start))
        let expectedEnd = try #require(Calendar.current.date(byAdding: .day, value: 1, to: end))

        #expect(duplicate.title == "Medication" + String(localized: .taskCopySuffix))
        #expect(duplicate.schedules.count == 1)
        #expect(duplicateSchedule.scheduledDate == expectedStart)
        #expect(duplicateSchedule.endDate == expectedEnd)
        #expect(spy.savedTasks.map(\.id) == [duplicate.id])
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
