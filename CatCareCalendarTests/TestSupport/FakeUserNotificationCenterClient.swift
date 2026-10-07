import Foundation
import UserNotifications
@testable import CatCareCalendar

@MainActor
final class FakeUserNotificationCenterClient: UserNotificationCenterClient {
    var delegate: UNUserNotificationCenterDelegate?
    var authorizationStatusValue: UNAuthorizationStatus = .authorized
    var deliveredSnapshots: [DeliveredNotificationSnapshot] = []
    var pendingRequests: [UNNotificationRequest] = []
    var addedRequests: [UNNotificationRequest] = []
    var removedDeliveredIdentifiers: [[String]] = []
    var removedPendingIdentifiers: [[String]] = []
    var removedAllDeliveredNotifications = false
    var removedAllPendingNotifications = false
    var badgeCounts: [Int] = []
    var categories: [Set<UNNotificationCategory>] = []
    var requestAuthorizationResult = true
    var addError: (any Error)?
    /// Runs before each `add`, so a test can hold a schedule pass open.
    var addHandler: (@MainActor () async -> Void)?
    var requestAuthorizationError: Error?
    var lastRequestedAuthorizationOptions: UNAuthorizationOptions?
    var deliveredNotificationSnapshotsHandler: (@MainActor () async -> [DeliveredNotificationSnapshot])?

    func add(_ request: UNNotificationRequest) async throws {
        await addHandler?()
        if let addError {
            throw addError
        }
        addedRequests.append(request)
        // As the system does: an add with a pending identifier replaces that request.
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func deliveredNotificationSnapshots() async -> [DeliveredNotificationSnapshot] {
        if let deliveredNotificationSnapshotsHandler {
            return await deliveredNotificationSnapshotsHandler()
        }
        return deliveredSnapshots
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removeAllDeliveredNotifications() {
        removedAllDeliveredNotifications = true
        deliveredSnapshots = []
    }

    func removeAllPendingNotificationRequests() {
        removedAllPendingNotifications = true
        pendingRequests = []
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
        deliveredSnapshots.removeAll { identifiers.contains($0.identifier) }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        lastRequestedAuthorizationOptions = options
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return requestAuthorizationResult
    }

    func setBadgeCount(_ badgeCount: Int) {
        badgeCounts.append(badgeCount)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories.append(categories)
    }
}
