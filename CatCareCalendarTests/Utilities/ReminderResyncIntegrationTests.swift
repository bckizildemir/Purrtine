import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import CatCareCalendar

/// The full resync end to end: `NotificationResyncCoordinator` reading a real store and driving the
/// real `NotificationManager` on a fake notification center.
@MainActor
struct ReminderResyncIntegrationTests {
    @Test
    func aFailedTaskFetchLeavesThePendingSetUntouched() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let fakeCenter = FakeUserNotificationCenterClient()
        let existing = pendingRequest(identifier: "\(UUID().uuidString)_existing", taskId: UUID())
        fakeCenter.pendingRequests = [existing]
        let manager = try await makeManager(notificationCenter: fakeCenter)
        let sut = NotificationResyncCoordinator(
            modelContainer: container,
            notificationManager: manager,
            fetchTasks: { _ in throw FetchFailure.unavailable }
        )

        await #expect(throws: FetchFailure.unavailable) {
            try await sut.resync()
        }

        #expect(fakeCenter.pendingRequests.map(\.identifier) == [existing.identifier])
        #expect(fakeCenter.removedPendingIdentifiers.isEmpty)
        #expect(fakeCenter.addedRequests.isEmpty)
    }

    @Test
    func aCompletionCommittedInAnotherContextMovesRemindersToTheNextOccurrence() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let fixture = try insertDailyTask(in: container.mainContext)
        let fakeCenter = FakeUserNotificationCenterClient()
        let manager = try await makeManager(notificationCenter: fakeCenter)
        let sut = NotificationResyncCoordinator(modelContainer: container, notificationManager: manager)
        try await sut.resync()
        #expect(fakeCenter.pendingRequests.contains { $0.identifier.contains(fixture.scheduleId.uuidString) })

        // As `NotificationActionCoordinator` does: its own context, its own commit.
        let actionContext = ModelContext(container)
        let taskId = fixture.taskId
        let task = try #require(
            try actionContext.fetch(FetchDescriptor<CareTask>(predicate: #Predicate { $0.id == taskId })).first
        )
        try TaskActionService.recordCompletion(of: task, with: CareTaskCompletionInput(), in: actionContext)
        try actionContext.save()
        let nextScheduleId = try #require(task.activeSchedule?.id)
        try await sut.resync()

        let identifiers = fakeCenter.pendingRequests.map(\.identifier)
        #expect(nextScheduleId != fixture.scheduleId)
        #expect(identifiers.isEmpty == false)
        #expect(identifiers.allSatisfy { $0.contains(nextScheduleId.uuidString) })
    }

    @Test(.timeLimit(.minutes(1)))
    func resyncWaitsForTheNewestPassWhenANewerRequestCancelsItsOwn() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let gate = ResyncGate()
        let sut = NotificationResyncCoordinator(modelContainer: container, notificationManager: gate)

        let waiter = Task { try await sut.resync() }
        await gate.waitUntilFirstPassStarts()
        let newerPass = sut.scheduleResync()
        gate.releaseFirstPass()
        try await waiter.value

        // The awaited pass was cancelled and threw; the waiter returned only once the newer pass
        // had completed.
        #expect(gate.startedPassCount == 2)
        #expect(gate.completedPassCount == 1)
        try await newerPass.value
    }

    @Test(.timeLimit(.minutes(1)))
    func backToBackRequestsCoalesceIntoTheNewestPass() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let gate = ResyncGate()
        let sut = NotificationResyncCoordinator(modelContainer: container, notificationManager: gate)

        let first = sut.scheduleResync()
        await gate.waitUntilFirstPassStarts()
        _ = sut.scheduleResync()
        _ = sut.scheduleResync()
        let last = sut.scheduleResync()
        gate.releaseFirstPass()
        try await last.value

        // The middle two were cancelled before they read the store.
        #expect(gate.startedPassCount == 2)
        #expect(gate.completedPassCount == 1)
        await #expect(throws: CancellationError.self) {
            try await first.value
        }
    }

    // MARK: - Helpers

    private func insertDailyTask(in context: ModelContext) throws -> (taskId: UUID, scheduleId: UUID) {
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        let task = CareTask(title: "Feed Mochi")
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.startOfDay(for: Date()).addingTimeInterval(23 * 3_600),
            frequency: .daily,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: 15
        )
        task.assignedCaregiver = caregiver
        schedule.task = task
        task.schedules = [schedule]
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()
        return (task.id, schedule.id)
    }

    private func makeManager(notificationCenter: FakeUserNotificationCenterClient) async throws -> NotificationManager {
        let defaults = try #require(UserDefaults(suiteName: "ReminderResyncIntegrationTests.\(UUID().uuidString)"))
        let sut = NotificationManager(
            notificationCenter: notificationCenter,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
        await sut.checkAuthorizationStatus()
        return sut
    }

    private func pendingRequest(identifier: String, taskId: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskId": taskId.uuidString]
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}

private enum FetchFailure: Error {
    case unavailable
}

/// Holds the first pass open until released, then lets it notice its cancellation the way
/// `NotificationManager` does between adds.
@MainActor
private final class ResyncGate: NotificationResyncing {
    private(set) var startedPassCount = 0
    private(set) var completedPassCount = 0
    private var firstPassStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstPassRelease: CheckedContinuation<Void, Never>?

    func resyncCareTaskNotifications(with infos: [NotificationScheduleInfo]) async throws {
        startedPassCount += 1
        if startedPassCount == 1 {
            firstPassStartWaiters.forEach { $0.resume() }
            firstPassStartWaiters = []
            await withCheckedContinuation { firstPassRelease = $0 }
        }
        try Task.checkCancellation()
        completedPassCount += 1
    }

    func waitUntilFirstPassStarts() async {
        if startedPassCount > 0 { return }
        await withCheckedContinuation { firstPassStartWaiters.append($0) }
    }

    func releaseFirstPass() {
        firstPassRelease?.resume()
        firstPassRelease = nil
    }
}
