import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationDebugStoreTests {
    @Test
    func snapshotsReplaceDuplicateIdentifiersAndSortByDate() async {
        let sut = NotificationDebugStore()
        let firstTaskId = UUID()
        let replacementTaskId = UUID()

        await sut.recordPendingNotification(
            id: "same-id",
            taskId: firstTaskId,
            taskTitle: "Old",
            body: "Old body",
            scheduledDate: Date(timeIntervalSince1970: 300)
        )
        await sut.recordPendingNotification(
            id: "later-id",
            taskId: firstTaskId,
            taskTitle: "Later",
            body: "Later body",
            scheduledDate: Date(timeIntervalSince1970: 200)
        )
        await sut.recordPendingNotification(
            id: "same-id",
            taskId: replacementTaskId,
            taskTitle: "Replacement",
            body: "Updated body",
            scheduledDate: Date(timeIntervalSince1970: 100)
        )

        let snapshots = await sut.pendingNotificationSnapshots()

        #expect(snapshots.map(\.id) == ["same-id", "later-id"])
        #expect(snapshots.first?.taskId == replacementTaskId)
        #expect(snapshots.first?.taskTitle == "Replacement")
        #expect(snapshots.first?.body == "Updated body")
    }

    @Test
    func removalSupportsTaskScopedAndCompleteCleanup() async {
        let sut = NotificationDebugStore()
        let removedTaskId = UUID()
        let retainedTaskId = UUID()
        for id in ["first", "second"] {
            await sut.recordPendingNotification(
                id: id,
                taskId: removedTaskId,
                taskTitle: id,
                body: id,
                scheduledDate: Date()
            )
        }
        await sut.recordPendingNotification(
            id: "retained",
            taskId: retainedTaskId,
            taskTitle: "Retained",
            body: "Retained",
            scheduledDate: Date()
        )

        await sut.removePendingNotifications(forTaskId: removedTaskId)
        #expect(await sut.pendingNotificationSnapshots().map(\.id) == ["retained"])

        await sut.removeAllPendingNotifications()
        #expect(await sut.pendingNotificationSnapshots().isEmpty)
    }
}

@Suite
struct DeliveredNotificationSnapshotTests {
    @Test
    func userInfoInitializerParsesSupportedValues() {
        let taskId = UUID()
        let sut = DeliveredNotificationSnapshot(
            identifier: "notification",
            userInfo: [
                "taskId": taskId.uuidString,
                "testNotification": true,
                "ignored": "value"
            ]
        )

        #expect(sut.identifier == "notification")
        #expect(sut.taskId == taskId)
        #expect(sut.isTestNotification)
    }

    @Test
    func userInfoInitializerRejectsUnsupportedTypes() {
        let unsupportedPayloads: [[AnyHashable: Any]] = [
            [:],
            ["taskId": "not-a-uuid"],
            ["taskId": UUID()],
            ["testNotification": "true"],
            ["testNotification": 1]
        ]

        for userInfo in unsupportedPayloads {
            let sut = DeliveredNotificationSnapshot(identifier: "notification", userInfo: userInfo)

            #expect(sut.taskId == nil)
            #expect(sut.isTestNotification == false)
        }
    }
}

@MainActor
private final class NotificationResyncSpy: NotificationResyncing {
    private(set) var receivedInfos: [[NotificationScheduleInfo]] = []
    private(set) var appliedTaskTitles: [String] = []
    private var isFirstCallStarted = false
    private var firstCallStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstCallRelease: CheckedContinuation<Void, Never>?
    var suspendsFirstCall = false

    func resyncCareTaskNotifications(with infos: [NotificationScheduleInfo]) async {
        receivedInfos.append(infos)
        if suspendsFirstCall, receivedInfos.count == 1 {
            isFirstCallStarted = true
            firstCallStartWaiters.forEach { $0.resume() }
            firstCallStartWaiters = []
            await withCheckedContinuation { continuation in
                firstCallRelease = continuation
            }
        }
        appliedTaskTitles.append(contentsOf: infos.map(\.taskTitle))
    }

    func waitUntilFirstCallStarts() async {
        if isFirstCallStarted { return }
        await withCheckedContinuation { continuation in
            firstCallStartWaiters.append(continuation)
        }
    }

    func releaseFirstCall() {
        firstCallRelease?.resume()
        firstCallRelease = nil
    }
}

@Suite
@MainActor
struct NotificationResyncCoordinatorTests {
    @Test
    func resyncMapsOnlyActiveSchedules() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let cat = Cat(name: "Mochi")
        let task = CareTask(
            title: "Medication",
            description: "Give tablet",
            category: .medication,
            iconName: "pills",
            priority: .urgent
        )
        task.assignedCats = [cat]
        let active = CareTaskSchedule(
            scheduledDate: Date(timeIntervalSince1970: 100),
            scheduledTime: Date(timeIntervalSince1970: 200),
            frequency: .weekly,
            frequencyInterval: 2,
            endDate: Date(timeIntervalSince1970: 500),
            reminderMinutes: 30,
            customDays: [1, 3]
        )
        let inactive = CareTaskSchedule(scheduledDate: Date(), frequency: .daily)
        active.task = task
        inactive.task = task
        inactive.isActive = false
        task.schedules = [active, inactive]
        context.insert(cat)
        context.insert(task)
        context.insert(active)
        context.insert(inactive)
        try context.save()
        let spy = NotificationResyncSpy()
        let sut = NotificationResyncCoordinator(modelContainer: container, notificationManager: spy)

        try await sut.resyncNow()

        let infos = try #require(spy.receivedInfos.first)
        let info = try #require(infos.first)
        #expect(infos.count == 1)
        #expect(info.scheduleId == active.id)
        #expect(info.taskId == task.id)
        #expect(info.taskTitle == "Medication")
        #expect(info.taskDescription == "Give tablet")
        #expect(info.catNames == "Mochi")
        #expect(info.category == .medication)
        #expect(info.iconName == "pills")
        #expect(info.priority == .urgent)
        #expect(info.frequency == .weekly)
        #expect(info.frequencyInterval == 2)
        #expect(info.customDays == [1, 3])
        #expect(info.reminderMinutes == 30)
    }

    @Test
    func scheduledResyncAppliesLatestSnapshotLastWhenCancelledWorkIgnoresCancellation() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let task = CareTask(title: "Stale", category: .feeding, iconName: "fork.knife")
        let schedule = CareTaskSchedule(
            scheduledDate: Date().addingTimeInterval(3_600),
            frequency: .once,
            reminderMinutes: 15
        )
        schedule.task = task
        task.schedules = [schedule]
        container.mainContext.insert(task)
        container.mainContext.insert(schedule)
        try container.mainContext.save()
        let spy = NotificationResyncSpy()
        spy.suspendsFirstCall = true
        let sut = NotificationResyncCoordinator(modelContainer: container, notificationManager: spy)

        _ = sut.scheduleResync()
        await spy.waitUntilFirstCallStarts()
        task.title = "Latest"
        try container.mainContext.save()
        let latestResync = sut.scheduleResync()
        spy.releaseFirstCall()
        try await latestResync.value

        #expect(spy.appliedTaskTitles == ["Stale", "Latest"])
        #expect(spy.appliedTaskTitles.last == "Latest")
    }
}
