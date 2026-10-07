import Foundation
import Testing
import UserNotifications
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationManagerBadgeTests {
    @Test
    func deliveredCareTaskNotificationsDriveBadgeCount() async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(identifier: "delivered-1", taskId: taskId, isTestNotification: false),
            DeliveredNotificationSnapshot(identifier: "delivered-2", taskId: UUID(), isTestNotification: false)
        ]
        fakeCenter.pendingRequests = Array(repeating: makePendingRequest(taskId: taskId), count: 8)

        let sut = try makeManager(notificationCenter: fakeCenter)

        await sut.syncBadgeCount()

        #expect(fakeCenter.badgeCounts.last == 2)
    }

    @Test
    func pendingRequestsDoNotAffectActivationBadgeSync() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.pendingRequests = Array(repeating: makePendingRequest(taskId: UUID()), count: 12)
        fakeCenter.badgeCounts = [60]

        let sut = try makeManager(notificationCenter: fakeCenter)

        await sut.syncBadgeCountIfNeededOnActivation()

        #expect(fakeCenter.badgeCounts.last == 0)
    }

    @Test
    func badgePolicyIgnoresTestNotificationsAndInvalidTaskIdentifiers() async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(identifier: "valid", taskId: taskId, isTestNotification: false),
            DeliveredNotificationSnapshot(identifier: "test", taskId: taskId, isTestNotification: true),
            DeliveredNotificationSnapshot(identifier: "invalid", taskId: nil, isTestNotification: false)
        ]

        let sut = try makeManager(notificationCenter: fakeCenter)

        await sut.syncBadgeCount()

        #expect(fakeCenter.badgeCounts.last == 1)
    }

    @Test
    func disablingBadgesClearsBadgeImmediately() throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(identifier: "valid", taskId: taskId, isTestNotification: false)
        ]
        fakeCenter.badgeCounts = [1]

        let sut = try makeManager(notificationCenter: fakeCenter)
        var settings = NotificationSettings.default
        settings.badgeEnabled = false

        _ = sut.applySettings(settings)

        #expect(fakeCenter.badgeCounts.last == 0)
    }

    @Test
    func activationSyncPreservesUnreadDeliveredReminderCount() async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(identifier: "valid", taskId: taskId, isTestNotification: false)
        ]
        fakeCenter.badgeCounts = [7]

        let sut = try makeManager(notificationCenter: fakeCenter)

        await sut.syncBadgeCountIfNeededOnActivation()

        #expect(fakeCenter.badgeCounts.last == 1)
    }

    @Test
    func slowerEarlierBadgeSyncCannotOverwriteLaterSnapshot() async throws {
        let stale = [
            DeliveredNotificationSnapshot(identifier: "stale-1", taskId: UUID(), isTestNotification: false),
            DeliveredNotificationSnapshot(identifier: "stale-2", taskId: UUID(), isTestNotification: false)
        ]
        let latest = [
            DeliveredNotificationSnapshot(identifier: "latest", taskId: UUID(), isTestNotification: false)
        ]
        let gate = BadgeSnapshotGate(stale: stale, latest: latest)
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredNotificationSnapshotsHandler = { await gate.nextSnapshot() }
        let sut = try makeManager(notificationCenter: fakeCenter)

        let earlierSync = Task { await sut.syncBadgeCount() }
        await gate.waitUntilFirstSnapshotStarts()
        await sut.syncBadgeCount()
        gate.releaseFirstSnapshot()
        await earlierSync.value

        #expect(fakeCenter.badgeCounts == [1])
    }

    @Test
    func clearingBadgeInvalidatesAnInFlightSnapshot() async throws {
        let stale = [
            DeliveredNotificationSnapshot(identifier: "stale", taskId: UUID(), isTestNotification: false)
        ]
        let gate = BadgeSnapshotGate(stale: stale, latest: [])
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredNotificationSnapshotsHandler = { await gate.nextSnapshot() }
        let sut = try makeManager(notificationCenter: fakeCenter)

        let inFlightSync = Task { await sut.syncBadgeCount() }
        await gate.waitUntilFirstSnapshotStarts()
        sut.clearBadge()
        gate.releaseFirstSnapshot()
        await inFlightSync.value

        #expect(fakeCenter.badgeCounts == [0])
    }

    private func makeManager(notificationCenter: FakeUserNotificationCenterClient) throws -> NotificationManager {
        let defaults = try #require(
            UserDefaults(suiteName: "NotificationManagerBadgeTests.\(UUID().uuidString)")
        )
        return NotificationManager(
            notificationCenter: notificationCenter,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
    }

    private func makePendingRequest(taskId: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskId": taskId.uuidString]
        return UNNotificationRequest(
            identifier: "pending-\(taskId.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
    }
}

@MainActor
private final class BadgeSnapshotGate {
    private let stale: [DeliveredNotificationSnapshot]
    private let latest: [DeliveredNotificationSnapshot]
    private var callCount = 0
    private var isFirstSnapshotStarted = false
    private var firstSnapshotStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstSnapshotRelease: CheckedContinuation<Void, Never>?

    init(stale: [DeliveredNotificationSnapshot], latest: [DeliveredNotificationSnapshot]) {
        self.stale = stale
        self.latest = latest
    }

    func nextSnapshot() async -> [DeliveredNotificationSnapshot] {
        callCount += 1
        guard callCount == 1 else { return latest }

        isFirstSnapshotStarted = true
        firstSnapshotStartWaiters.forEach { $0.resume() }
        firstSnapshotStartWaiters = []
        await withCheckedContinuation { continuation in
            firstSnapshotRelease = continuation
        }
        return stale
    }

    func waitUntilFirstSnapshotStarts() async {
        if isFirstSnapshotStarted { return }
        await withCheckedContinuation { continuation in
            firstSnapshotStartWaiters.append(continuation)
        }
    }

    func releaseFirstSnapshot() {
        firstSnapshotRelease?.resume()
        firstSnapshotRelease = nil
    }
}
