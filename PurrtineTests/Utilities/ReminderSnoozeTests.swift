import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Purrtine

/// Snoozes (#142): none for a finished occurrence or a deleted task, none with Reminders off, and
/// never more than the four slots iOS's 64 leave after 59 reminders and the nudge.
@MainActor
struct ReminderSnoozeTests {
    // MARK: - Completion race

    @Test(.timeLimit(.minutes(1)))
    func aSnoozeWhosePermissionCheckIsOpenWhenTheTaskIsCompletedNeverLands() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let task = makeTask()
        let gate = PermissionGate()
        fakeCenter.authorizationStatusHandler = { await gate.hold() }

        let snooze = Task {
            try await sut.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10)
        }
        await gate.waitUntilHeld()
        // What `CareTaskWriter.complete` does while the permission check is still open.
        await sut.cancelSnoozedNotifications(forTaskId: task.id)
        gate.release()
        try await snooze.value

        #expect(fakeCenter.pendingRequests.filter { $0.identifier.hasPrefix("snooze_") }.isEmpty)
        #expect(fakeCenter.addedRequests.isEmpty)
    }

    @Test
    func aSnoozeAfterACompletionOfAnotherTaskStillLands() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let task = makeTask()

        await sut.cancelSnoozedNotifications(forTaskId: UUID())
        try await sut.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10)

        #expect(fakeCenter.pendingRequests.count == 1)
    }

    // MARK: - Deleted task

    @Test
    func deletingACatRemovesTheSnoozeOfATaskOnlyThatCatHad() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let manager = try await makeManager(notificationCenter: fakeCenter)
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let coordinator = NotificationResyncCoordinator(modelContainer: container, notificationManager: manager)
        manager.onFullResyncAwaited = { try await coordinator.resync() }
        let context = container.mainContext
        let cat = Cat(name: "Mochi")
        let task = makeTask()
        let schedule = CareTaskSchedule(
            scheduledDate: Date().addingTimeInterval(86_400),
            frequency: .once,
            frequencyInterval: 1,
            reminderMinutes: 15
        )
        task.assignedCats = [cat]
        schedule.task = task
        task.schedules = [schedule]
        context.insert(cat)
        context.insert(task)
        context.insert(schedule)
        try context.save()
        let taskId = task.id
        try await manager.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10)
        try #require(fakeCenter.pendingRequests.contains { $0.identifier.hasPrefix("snooze_") })
        let sut = CatDeletionService(taskWriter: CareTaskWriter(scheduler: manager), deletePhoto: { _ in })

        try await sut.delete(cat, from: context)

        #expect(fakeCenter.pendingRequests.contains { $0.content.userInfo["taskId"] as? String == taskId.uuidString } == false)
    }

    @Test
    func aFullResyncRemovesASnoozeWhoseTaskIsNoLongerInTheStore() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let keptTask = makeTask()
        let goneTask = makeTask()
        try await sut.scheduleSnoozedNotification(for: info(for: keptTask), delayMinutes: 10)
        try await sut.scheduleSnoozedNotification(for: info(for: goneTask), delayMinutes: 10)

        try await sut.resyncCareTaskNotifications(with: [reminderInfo(taskId: keptTask.id)])

        let snoozedTaskIds = fakeCenter.pendingRequests
            .filter { $0.identifier.hasPrefix("snooze_") }
            .compactMap { $0.content.userInfo["taskId"] as? String }
        #expect(snoozedTaskIds == [keptTask.id.uuidString])
    }

    // MARK: - Reminders off

    @Test
    func noSnoozeIsAddedWhileRemindersAreOffInTheAppSettings() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        var settings = NotificationSettings.default
        settings.isEnabled = false
        let sut = try await makeManager(notificationCenter: fakeCenter, settings: settings)

        try await sut.scheduleSnoozedNotification(for: info(for: makeTask()), delayMinutes: 10)

        #expect(fakeCenter.addedRequests.isEmpty)
        #expect(fakeCenter.pendingRequests.isEmpty)
    }

    @Test
    func aSnoozeTappedAfterRemindersWereTurnedOffIsNotAdded() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let task = makeTask()
        try await sut.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10)
        var settings = sut.settings
        settings.isEnabled = false
        sut.applySettings(settings)
        try await sut.resyncCareTaskNotifications(with: [reminderInfo(taskId: task.id)])
        try #require(fakeCenter.pendingRequests.isEmpty)

        try await sut.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10)

        #expect(fakeCenter.pendingRequests.isEmpty)
    }

    // MARK: - Cap

    @Test
    func aFifthSnoozeReplacesTheOldestAndTheTotalStaysWithinSixtyFour() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        try await sut.resyncCareTaskNotifications(with: try await starterTaskInfos())
        try #require(fakeCenter.pendingRequests.count == 60)
        let tasks = (0..<5).map { _ in makeTask() }
        for (index, task) in tasks.prefix(4).enumerated() {
            fakeCenter.pendingRequests.append(
                pendingRequest(identifier: "snooze_\(task.id.uuidString)_\(index + 1)", taskId: task.id)
            )
        }
        try #require(fakeCenter.pendingRequests.count == 64)

        try await sut.scheduleSnoozedNotification(for: info(for: tasks[4]), delayMinutes: 10)

        let snoozes = fakeCenter.pendingRequests.filter { $0.identifier.hasPrefix("snooze_") }
        let snoozedTaskIds = Set(snoozes.compactMap { $0.content.userInfo["taskId"] as? String })
        #expect(fakeCenter.pendingRequests.count <= 64)
        #expect(snoozes.count == 4)
        #expect(snoozedTaskIds == Set(tasks.dropFirst().map(\.id.uuidString)))
    }

    @Test(.timeLimit(.minutes(1)))
    func snoozesTappedTogetherNeverExceedTheFourSlots() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let tasks = (0..<6).map { _ in makeTask() }

        let snoozes = tasks.map { task in
            Task { try await sut.scheduleSnoozedNotification(for: info(for: task), delayMinutes: 10) }
        }
        for snooze in snoozes {
            try await snooze.value
        }

        #expect(fakeCenter.pendingRequests.filter { $0.identifier.hasPrefix("snooze_") }.count == 4)
    }

    // MARK: - Helpers

    private func makeTask() -> CareTask {
        let task = CareTask(title: "Feed Mochi", category: .feeding)
        task.assignedCats = [Cat(name: "Mochi")]
        return task
    }

    private func info(for task: CareTask) -> NotificationScheduleInfo {
        NotificationScheduleInfo(snoozing: task, firingAt: Date().addingTimeInterval(600))
    }

    private func reminderInfo(taskId: UUID) -> NotificationScheduleInfo {
        NotificationScheduleInfo(
            scheduleId: UUID(),
            taskId: taskId,
            taskTitle: "Feed Mochi",
            taskDescription: nil,
            catNames: "Mochi",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            scheduledDate: Date().addingTimeInterval(86_400),
            scheduledTime: nil,
            frequency: .once,
            frequencyInterval: 1,
            endDate: nil,
            customDays: nil,
            reminderMinutes: 0
        )
    }

    private func starterTaskInfos() async throws -> [NotificationScheduleInfo] {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        var tempData = TempCatData()
        tempData.name = "Luna"
        let builder = OnboardingDataBuilder(taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()))
        try await builder.createCatAndTasks(from: tempData, selectedTasks: [.feeding, .water, .litterBox], in: context)
        return try context.fetch(FetchDescriptor<CareTask>()).flatMap(NotificationScheduleInfo.activeInfos(for:))
    }

    private func makeManager(
        notificationCenter: FakeUserNotificationCenterClient,
        settings: NotificationSettings = .default
    ) async throws -> NotificationManager {
        let defaults = try #require(UserDefaults(suiteName: "ReminderSnoozeTests.\(UUID().uuidString)"))
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")
        store.save(settings)
        let sut = NotificationManager(notificationCenter: notificationCenter, settingsStore: store)
        await sut.checkAuthorizationStatus()
        return sut
    }

    private func pendingRequest(identifier: String, taskId: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskId": taskId.uuidString]
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}

/// Holds one permission read open until released.
@MainActor
private final class PermissionGate {
    private var isHeld = false
    private var heldWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var hasReleased = false

    func hold() async {
        guard hasReleased == false else { return }
        isHeld = true
        heldWaiters.forEach { $0.resume() }
        heldWaiters = []
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilHeld() async {
        if isHeld { return }
        await withCheckedContinuation { heldWaiters.append($0) }
    }

    func release() {
        hasReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
