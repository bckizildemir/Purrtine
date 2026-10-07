import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct CatDeletionServiceTests {
    @Test
    func deletingCatRemovesExclusiveTaskAndFinishesCleanupBeforeReturning() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let cat = Cat(name: "Mochi", photoURLs: ["mochi-1.jpg", "mochi-2.jpg"])
        let task = CareTask(title: "Brush Mochi", category: .grooming)
        task.assignedCats = [cat]
        context.insert(cat)
        context.insert(task)
        try context.save()
        var deletedPhotos: [String] = []
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let sut = CatDeletionService(
            taskWriter: CareTaskWriter(scheduler: spy),
            deletePhoto: { deletedPhotos.append($0) }
        )

        let summary = try await sut.delete(cat, from: context)

        #expect(deletedPhotos == ["mochi-1.jpg", "mochi-2.jpg"])
        #expect(summary.deletedPhotoFileNames == deletedPhotos)
        #expect(summary.deletedTaskIds == [task.id])
        #expect(spy.resyncCount == 1)
        #expect(spy.lastResyncedInfos.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTask>()).isEmpty)
    }

    @Test
    func deletingCatPreservesSharedTaskAndReschedulesForRemainingCatBeforeReturning() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let deletedCat = Cat(name: "Mochi")
        let remainingCat = Cat(name: "Luna")
        let task = CareTask(
            title: "Clean water bowls",
            description: "Refresh both bowls",
            category: .water,
            iconName: "drop.fill",
            priority: .high
        )
        task.assignedCats = [deletedCat, remainingCat]
        let scheduledDate = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduledTime = Date(timeIntervalSince1970: 1_800_036_000)
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            frequency: .weekly,
            frequencyInterval: 2,
            reminderMinutes: 45,
            customDays: [2, 5]
        )
        task.schedules = [schedule]
        context.insert(deletedCat)
        context.insert(remainingCat)
        context.insert(task)
        try context.save()
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let sut = CatDeletionService(taskWriter: CareTaskWriter(scheduler: spy), deletePhoto: { _ in })

        let summary = try await sut.delete(deletedCat, from: context)

        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let remainingTask = try #require(tasks.first)
        #expect(tasks.count == 1)
        #expect(remainingTask.id == task.id)
        #expect(remainingTask.assignedCats.map(\.name) == ["Luna"])
        #expect(summary.deletedTaskIds.isEmpty)

        let rescheduleGroup = spy.lastResyncedInfos
        let rescheduleInfo = try #require(rescheduleGroup.first)
        #expect(spy.resyncCount == 1)
        #expect(rescheduleGroup.count == 1)
        #expect(rescheduleInfo.scheduleId == schedule.id)
        #expect(rescheduleInfo.taskId == task.id)
        #expect(rescheduleInfo.taskTitle == "Clean water bowls")
        #expect(rescheduleInfo.taskDescription == "Refresh both bowls")
        #expect(rescheduleInfo.catNames == "Luna")
        #expect(rescheduleInfo.category == .water)
        #expect(rescheduleInfo.iconName == "drop.fill")
        #expect(rescheduleInfo.priority == .high)
        #expect(rescheduleInfo.scheduledDate == scheduledDate)
        #expect(rescheduleInfo.scheduledTime == scheduledTime)
        #expect(rescheduleInfo.frequency == .weekly)
        #expect(rescheduleInfo.frequencyInterval == 2)
        #expect(rescheduleInfo.customDays == [2, 5])
        #expect(rescheduleInfo.reminderMinutes == 45)
    }

    /// The cat is gone once the delete commits, so a reminder failure after it must not make the
    /// delete look failed to the view, which would then keep a sheet open over a deleted cat.
    @Test
    func deletingCatSucceedsWhenTheReminderRefreshFails() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let cat = Cat(name: "Mochi")
        let task = CareTask(title: "Brush Mochi", category: .grooming)
        task.assignedCats = [cat]
        context.insert(cat)
        context.insert(task)
        try context.save()
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        spy.resyncError = .forcedFailure
        let sut = CatDeletionService(taskWriter: CareTaskWriter(scheduler: spy), deletePhoto: { _ in })

        let summary = try await sut.delete(cat, from: context)

        #expect(summary.deletedTaskIds == [task.id])
        #expect(spy.resyncAttemptCount == 1)
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
    }
}
