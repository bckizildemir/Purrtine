import Foundation
import SwiftUI
import UserNotifications

// MARK: - Notification Categories
enum NotificationCategory: String, CaseIterable {
    case taskReminder = "TASK_REMINDER"
    case taskOverdue = "TASK_OVERDUE"
    case taskUpcoming = "TASK_UPCOMING"
    case medicationCritical = "MEDICATION_CRITICAL"
    
    var identifier: String { rawValue }
    
    var actions: [UNNotificationAction] {
        switch self {
        case .taskReminder, .taskUpcoming:
            return [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: String(localized: .notificationActionComplete),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_10MIN",
                    title: String(localized: .notificationActionRemind10Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_30MIN",
                    title: String(localized: .notificationActionRemind30Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_1HOUR",
                    title: String(localized: .notificationActionRemind1Hour),
                    options: []
                )
            ]
        case .taskOverdue:
            return [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: String(localized: .notificationActionComplete),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_10MIN",
                    title: String(localized: .notificationActionRemind10Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_30MIN",
                    title: String(localized: .notificationActionRemind30Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_1HOUR",
                    title: String(localized: .notificationActionRemind1Hour),
                    options: []
                )
            ]
        case .medicationCritical:
            return [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: String(localized: .notificationActionComplete),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_10MIN",
                    title: String(localized: .notificationActionRemind10Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_30MIN",
                    title: String(localized: .notificationActionRemind30Min),
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_1HOUR",
                    title: String(localized: .notificationActionRemind1Hour),
                    options: []
                )
            ]
        }
    }
}

// MARK: - Notification Settings
nonisolated struct NotificationSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool = true
    var overdueReminderDelayMinutes: Int? = 60
    var criticalTasksOnly: Bool = false
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    var showTaskDetails: Bool = true
    
    // Category specific settings
    var enabledCategories: Set<CareTaskCategory> = Set(CareTaskCategory.allCases)
    
    static let `default` = NotificationSettings()
}

// MARK: - Notification Schedule Info
struct NotificationScheduleInfo: Sendable {
    let scheduleId: UUID
    let taskId: UUID
    let taskTitle: String
    let taskDescription: String?
    let catNames: String
    let category: CareTaskCategory
    let iconName: String
    let priority: CareTaskPriority
    let scheduledDate: Date
    let scheduledTime: Date?
    let frequency: CareTaskFrequency
    let frequencyInterval: Int
    let endDate: Date?
    let customDays: [Int]?
    let reminderMinutes: Int?
}

enum NotificationDelayError: Error, Equatable {
    case invalidMinutes
}

#if DEBUG
/// Failure injected by the `-fail-notification-schedule` UI-test launch argument.
///
/// It exists so the UI tests can reach the failure alerts that `disablesRealNotifications`
/// otherwise makes unreachable. It is compiled into Debug builds only, and
/// `AppLaunchConfiguration.failsNotificationSchedule` gates it on `-ui-testing` on top of that, so
/// a release build cannot reach it at all.
enum NotificationTestFailure: Error, Equatable {
    case injectedByUITest
}
#endif

enum NotificationSchedulingEligibility {
    static func allows(
        info: NotificationScheduleInfo,
        settings: NotificationSettings,
        authorizationStatus: UNAuthorizationStatus
    ) -> Bool {
        settings.isEnabled
            && authorizationStatus.allowsReminderConfiguration
            && (info.reminderMinutes ?? -1) >= 0
            && (settings.criticalTasksOnly == false || info.priority == .urgent)
            && settings.enabledCategories.contains(info.category)
    }
}

// MARK: - Notification Manager
@MainActor
@Observable
final class NotificationManager:
    NSObject,
    TaskNotificationScheduling,
    NotificationAuthorizationChecking,
    NotificationResyncing
{
    nonisolated static let shared: NotificationManager = MainActor.assumeIsolated {
        NotificationManager()
    }

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var settings: NotificationSettings
    var actionCoordinator: NotificationActionCoordinator?

    /// How far past its first occurrence a recurring series may materialize reminders.
    /// See `calculateReminderOccurrences(for:offsetMinutes:now:)`.
    private static let schedulingHorizonMonths = 12

    private let notificationCenter: any UserNotificationCenterClient
    private let settingsStore: NotificationSettingsStore
    private var badgeSyncToken = UUID()
    /// The hook that `requestFullReminderResync()` calls. `CatCareCalendarApp` points it at
    /// `NotificationResyncCoordinator.scheduleResync()`, which rebuilds every care-task reminder from
    /// the store. Call `requestFullReminderResync()` rather than this directly.
    var onFullResyncRequested: (@MainActor () -> Void)?
    /// The hook that `resyncAllCareTaskReminders()` awaits. `CatCareCalendarApp` points it at
    /// `NotificationResyncCoordinator.resync()`, which waits for the newest pass. Without it — in a
    /// preview, which has no coordinator and must not schedule — the resync does nothing.
    var onFullResyncAwaited: (@MainActor () async throws -> Void)?

    private override init() {
        self.notificationCenter = SystemUserNotificationCenterClient()
        self.settingsStore = NotificationSettingsStore()
        self.settings = settingsStore.load()
        super.init()
        setupNotificationCategories()
        notificationCenter.delegate = self
    }

    init(
        notificationCenter: any UserNotificationCenterClient,
        settingsStore: NotificationSettingsStore? = nil
    ) {
        self.notificationCenter = notificationCenter
        let resolvedSettingsStore = settingsStore ?? NotificationSettingsStore()
        self.settingsStore = resolvedSettingsStore
        self.settings = resolvedSettingsStore.load()
        super.init()
        setupNotificationCategories()
        self.notificationCenter.delegate = self
    }

    // MARK: - SF Symbol to Emoji Mapping
    private func emojiForCategory(_ category: CareTaskCategory) -> String {
        switch category {
        case .feeding:
            return "🍽️"
        case .water:
            return "💧"
        case .medication:
            return "💊"
        case .grooming:
            return "✂️"
        case .health:
            return "❤️"
        case .exercise:
            return "🎾"
        case .litter:
            return "🚽"
        case .vet:
            return "🏥"
        case .general:
            return "📝"
        }
    }
    
    // MARK: - Setup
    private func setupNotificationCategories() {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: [],
                options: [.customDismissAction, .allowInCarPlay]
            )
        }

        notificationCenter.setNotificationCategories(Set(categories))
    }

    // MARK: - Permission Management
    func requestPermission() async -> Bool {
        if AppLaunchConfiguration.current.disablesRealNotifications {
            authorizationStatus = .denied
            return false
        }

        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .providesAppNotificationSettings]
            )

            authorizationStatus = granted ? .authorized : .denied
            if granted { requestFullReminderResync() }

            return granted
        } catch {
            debugLog("Notification permission error: \(error)")
            authorizationStatus = .denied
            return false
        }
    }

    func checkAuthorizationStatus() async {
        if await updateAuthorizationStatus() {
            requestFullReminderResync()
        }
    }

    /// App activation: recount the badge, refresh the permission, then top up the reminders.
    /// Reminders that fired since the last pass freed their slots, and nothing else refills them
    /// until a task or setting changes. One request covers a permission change too, and
    /// `NotificationResyncCoordinator` coalesces back-to-back activations.
    func handleAppActivation() async {
        await syncBadgeCountIfNeededOnActivation()
        await updateAuthorizationStatus()
        requestFullReminderResync()
    }

    /// Reads the permission from the system. Returns whether reminder access changed.
    @discardableResult
    private func updateAuthorizationStatus() async -> Bool {
        let previousStatus = authorizationStatus
        if AppLaunchConfiguration.current.disablesRealNotifications {
            authorizationStatus = .denied
            return false
        }

        authorizationStatus = await notificationCenter.authorizationStatus()
        return previousStatus.allowsReminderConfiguration != authorizationStatus.allowsReminderConfiguration
    }

    func refreshAuthorizationStatusFromSystem() async -> UNAuthorizationStatus {
        let status = await notificationCenter.authorizationStatus()
        let didChangeAccess = authorizationStatus.allowsReminderConfiguration != status.allowsReminderConfiguration
        authorizationStatus = status
        if didChangeAccess { requestFullReminderResync() }
        return status
    }

    @discardableResult
    func applySettings(_ settings: NotificationSettings) -> NotificationSettingsMonitoringCommand {
        self.settings = settings
        settingsStore.save(settings)

        if settings.badgeEnabled {
            Task {
                await self.syncBadgeCount()
            }
        } else {
            clearBadge()
        }

        requestFullReminderResync()
        return NotificationSettingsApplication.monitoringCommand(for: settings, authorizationStatus: authorizationStatus)
    }

    /// Asks for one full resync, which rebuilds every care-task reminder from the store. Settings
    /// and permission changes ask for one, and so does any caller that knows some reminders went
    /// stale after a save.
    func requestFullReminderResync() {
        onFullResyncRequested?()
    }

    // MARK: - CareTask Notifications

    /// The writer's entry point: one full capped resync, awaited. See `onFullResyncAwaited`.
    func resyncAllCareTaskReminders() async throws {
        guard let onFullResyncAwaited else {
            // Only a preview may run without the hook. Anywhere else every writer verb would report
            // success with no resync behind it, which is the failure this assertion makes loud.
            assert(
                AppLaunchConfiguration.current.isRunningForPreviews,
                "NotificationManager.onFullResyncAwaited is not wired; reminders were not resynced"
            )
            return
        }
        try await onFullResyncAwaited()
    }

    /// Removes the pending snoozes of `taskId`. The writer calls it when the task is completed or
    /// deleted: a snooze belongs to an occurrence, and the full resync leaves snoozes alone, so a
    /// snooze for a finished occurrence would otherwise still fire and invite a second completion.
    func cancelSnoozedNotifications(forTaskId taskId: UUID) async {
        if AppLaunchConfiguration.current.disablesRealNotifications {
            await NotificationDebugStore.shared.removePendingNotifications(forTaskId: taskId)
            return
        }

        let snoozeIds = await notificationCenter.pendingNotificationRequests()
            .filter { Self.isSnooze($0) && $0.content.userInfo["taskId"] as? String == taskId.uuidString }
            .map(\.identifier)
        guard snoozeIds.isEmpty == false else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: snoozeIds)
    }

    /// Makes the pending care-task reminders match `infos`: every active schedule in the store.
    ///
    /// It builds every candidate reminder, keeps the `CareTaskReminderSelection.limit` soonest, and
    /// applies the result as a diff: it removes the care-task requests that are no longer selected and
    /// adds the selected ones that are missing or changed. Debug test requests are never touched, and
    /// snoozes only when reminders are off. With reminders turned off (settings or permission)
    /// nothing is selected, so the diff removes every care-task reminder and every snooze — that wipe
    /// is intended: the caregiver asked for silence.
    ///
    /// Throws when a request cannot be added, and `CancellationError` when cancelled. A cancelled pass
    /// can stop between adds; that stays safe because every cancellation comes from
    /// `NotificationResyncCoordinator.scheduleResync()`, which runs a successor pass over the whole set.
    func resyncCareTaskNotifications(with infos: [NotificationScheduleInfo]) async throws {
        #if DEBUG
        // UI-test-only; see `failsNotificationSchedule`. Checked before the stub's early return
        // below, which would otherwise leave nothing to throw.
        if AppLaunchConfiguration.current.failsNotificationSchedule {
            throw NotificationTestFailure.injectedByUITest
        }
        #endif
        guard AppLaunchConfiguration.current.disablesRealNotifications == false else { return }
        // A pass that runs before the first permission read — a cold launch from a notification
        // action — would otherwise read "not determined" as "reminders off" and wipe the whole set.
        if authorizationStatus == .notDetermined {
            await updateAuthorizationStatus()
        }
        try Task.checkCancellation()

        let areRemindersOn = settings.isEnabled && authorizationStatus.allowsReminderConfiguration
        let pendingCareTaskRequests = await notificationCenter.pendingNotificationRequests()
            .filter { Self.isCareTaskReminder($0) || (areRemindersOn == false && Self.isSnooze($0)) }
        try Task.checkCancellation()

        let wantedRequests = areRemindersOn ? selectedReminderRequests(for: infos) : []
        let wantedIds = Set(wantedRequests.map(\.identifier))
        let staleIds = pendingCareTaskRequests.map(\.identifier).filter { wantedIds.contains($0) == false }
        if staleIds.isEmpty == false {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIds)
        }

        let pendingById = Dictionary(
            pendingCareTaskRequests.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var addedCount = 0
        for request in wantedRequests {
            if let pending = pendingById[request.identifier], Self.isUnchanged(pending, comparedWith: request) {
                continue
            }
            try Task.checkCancellation()
            // An add with a pending identifier replaces that request, so a changed reminder is
            // updated in place.
            try await notificationCenter.add(request)
            addedCount += 1
        }
        debugLog(
            "Reminder resync: \(wantedRequests.count) selected, \(staleIds.count) removed, \(addedCount) added"
        )
    }

    /// The requests a resync wants pending: the soonest reminders across every eligible schedule.
    private func selectedReminderRequests(for infos: [NotificationScheduleInfo]) -> [UNNotificationRequest] {
        let now = Date()
        let candidates = infos
            .filter {
                NotificationSchedulingEligibility.allows(
                    info: $0,
                    settings: settings,
                    authorizationStatus: authorizationStatus
                )
            }
            .flatMap { reminderCandidates(for: $0, now: now) }

        return CareTaskReminderSelection.soonest(candidates).map { candidate in
            UNNotificationRequest(
                identifier: candidate.identifier,
                content: createNotificationContent(for: candidate.info, isOverdue: candidate.isOverdue),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: candidate.fireDate
                    ),
                    repeats: false
                )
            )
        }
    }

    /// Every reminder `info` could schedule: one per upcoming occurrence, plus one overdue follow-up
    /// for the next occurrence. An identifier names its occurrence by due date rather than by
    /// position, so it stays the same while earlier occurrences pass.
    private func reminderCandidates(
        for info: NotificationScheduleInfo,
        now: Date
    ) -> [CareTaskReminderCandidate] {
        let identifierPrefix = "\(info.taskId.uuidString)_\(info.scheduleId.uuidString)"
        var candidates = calculateReminderOccurrences(for: info, offsetMinutes: info.reminderMinutes ?? 0, now: now)
            .map { occurrence in
                CareTaskReminderCandidate(
                    identifier: "\(identifierPrefix)_\(Int(occurrence.dueDate.timeIntervalSince1970))",
                    fireDate: occurrence.fireDate,
                    info: info,
                    isOverdue: false
                )
            }

        if let delay = settings.overdueReminderDelayMinutes, delay > 0 {
            let (_, didDelayOverflow) = delay.multipliedReportingOverflow(by: 60)
            if didDelayOverflow == false,
               let dueDate = calculateReminderOccurrences(for: info, offsetMinutes: 0, now: now).first?.dueDate,
               let overdueDate = Calendar.current.date(byAdding: .minute, value: delay, to: dueDate),
               overdueDate > dueDate {
                candidates.append(
                    CareTaskReminderCandidate(
                        identifier: "\(identifierPrefix)_overdue_\(Int(dueDate.timeIntervalSince1970))",
                        fireDate: overdueDate,
                        info: info,
                        isOverdue: true
                    )
                )
            }
        }
        return candidates
    }

    /// A pending request the resync owns: it carries a task, and it is neither a snooze nor a debug
    /// test notification, both of which sit outside the reminder budget.
    private static func isCareTaskReminder(_ request: UNNotificationRequest) -> Bool {
        let userInfo = request.content.userInfo
        return userInfo["taskId"] != nil
            && request.identifier.hasPrefix("snooze_") == false
            && userInfo["testNotification"] as? Bool != true
    }

    /// A pending snooze for a task, as `scheduleSnoozedNotification` names it.
    private static func isSnooze(_ request: UNNotificationRequest) -> Bool {
        request.identifier.hasPrefix("snooze_") && request.content.userInfo["taskId"] != nil
    }

    /// Whether `pending` already says and fires what `wanted` does, so re-adding it would change
    /// nothing.
    private static func isUnchanged(
        _ pending: UNNotificationRequest,
        comparedWith wanted: UNNotificationRequest
    ) -> Bool {
        guard let pendingTrigger = pending.trigger as? UNCalendarNotificationTrigger,
              let wantedTrigger = wanted.trigger as? UNCalendarNotificationTrigger,
              pendingTrigger.dateComponents == wantedTrigger.dateComponents else { return false }
        let old = pending.content
        let new = wanted.content
        return old.title == new.title
            && old.subtitle == new.subtitle
            && old.body == new.body
            && old.categoryIdentifier == new.categoryIdentifier
            && old.threadIdentifier == new.threadIdentifier
            && old.badge == new.badge
            && (old.sound == nil) == (new.sound == nil)
            && NSDictionary(dictionary: old.userInfo).isEqual(to: new.userInfo)
    }

    private func createNotificationContent(for info: NotificationScheduleInfo, isOverdue: Bool = false) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if settings.showTaskDetails {
            let categoryEmoji = emojiForCategory(info.category)
            content.title = isOverdue ? "⚠️ \(String(localized: .notificationOverdueTitle))" : "\(categoryEmoji) \(String(localized: .notificationReminderTitle))"
            content.body = "\(info.taskTitle)\n🐱 \(info.catNames)"
        } else {
            content.title = String(localized: isOverdue ? .notificationOverdueGenericTitle : .notificationReminderGenericTitle)
            content.body = String(localized: .notificationGenericBody)
        }
        if settings.showTaskDetails, let description = info.taskDescription, !description.isEmpty {
            content.subtitle = description
        }
        content.sound = settings.soundEnabled ? .default : nil
        content.badge = badgeNumber
        content.threadIdentifier = info.taskId.uuidString

        // Use proper category identifier to enable notification actions
        let notificationCategory: NotificationCategory
        if isOverdue {
            notificationCategory = .taskOverdue
        } else if info.priority == .urgent && info.category == .medication {
            notificationCategory = .medicationCritical
        } else {
            notificationCategory = .taskReminder
        }
        content.categoryIdentifier = notificationCategory.identifier

        if settings.showTaskDetails {
            content.userInfo = [
                "taskId": info.taskId.uuidString,
                "taskTitle": info.taskTitle,
                "categoryIcon": info.iconName,
                "category": info.category.rawValue,
                "priority": info.priority.rawValue,
                "catNames": info.catNames
            ]
        } else {
            content.userInfo = ["taskId": info.taskId.uuidString]
        }
        return content
    }

    /// One upcoming occurrence of a series and the moment its reminder fires.
    private struct ReminderOccurrence {
        let dueDate: Date
        let fireDate: Date
    }

    private func calculateReminderOccurrences(
        for info: NotificationScheduleInfo,
        offsetMinutes: Int,
        now: Date
    ) -> [ReminderOccurrence] {
        let calendar = Calendar.current
        var baseDate = info.scheduledDate
        if let scheduledTime = info.scheduledTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            baseDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: baseDate) ?? baseDate
        }
        guard let occurrenceThreshold = calendar.date(
            byAdding: .minute,
            value: offsetMinutes,
            to: now
        ) else {
            return []
        }

        let schedule = CareTaskSchedule(
            scheduledDate: baseDate,
            frequency: info.frequency,
            frequencyInterval: info.frequencyInterval,
            endDate: info.endDate,
            customDays: info.customDays
        )
        let maximumCount: Int
        switch info.frequency {
        case .once:
            maximumCount = 1
        case .daily:
            maximumCount = 30
        case .weekly, .biweekly:
            maximumCount = 12
        case .monthly:
            maximumCount = 6
        case .custom:
            maximumCount = 20
        }

        var occurrences: [ReminderOccurrence] = []
        var occurrence = schedule.nextOccurrence(from: occurrenceThreshold, calendar: calendar)
        // Bound how far the materialized series may span. iOS keeps only the 64 soonest pending
        // requests per app, and this whole set is rebuilt on every resync, so occurrences decades
        // out only crowd out nearer ones without ever being delivered as planned. The repeat sheet
        // allows intervals up to 99 years (`.year` maps to `monthly` × 12), which otherwise placed
        // the six monthly slots centuries apart. Measured from the first occurrence rather than
        // from now, so a legitimately far-future series still gets its leading reminder.
        let horizon = occurrence.flatMap {
            calendar.date(byAdding: .month, value: Self.schedulingHorizonMonths, to: $0)
        }
        while let dueDate = occurrence, occurrences.count < maximumCount {
            if let horizon, dueDate > horizon { break }
            guard let reminderDate = calendar.date(
                byAdding: .minute,
                value: -offsetMinutes,
                to: dueDate
            ) else {
                break
            }
            if reminderDate > now {
                occurrences.append(ReminderOccurrence(dueDate: dueDate, fireDate: reminderDate))
            }
            occurrence = schedule.followingOccurrence(after: dueDate, calendar: calendar)
        }

        return occurrences
    }
    
    // MARK: - Quick Actions
    func scheduleSnoozedNotification(for info: NotificationScheduleInfo, delayMinutes: Int) async throws {
        let (delaySeconds, didOverflow) = delayMinutes.multipliedReportingOverflow(by: 60)
        guard delayMinutes > 0, didOverflow == false else {
            throw NotificationDelayError.invalidMinutes
        }
        let delayInterval = TimeInterval(delaySeconds)

        if AppLaunchConfiguration.current.disablesRealNotifications {
            await NotificationDebugStore.shared.recordPendingNotification(
                id: "debug_snooze_\(info.taskId.uuidString)",
                taskId: info.taskId,
                taskTitle: info.taskTitle,
                body: info.catNames,
                scheduledDate: info.scheduledDate
            )
            return
        }

        let refreshedStatus = await refreshAuthorizationStatusFromSystem()
        guard refreshedStatus == .authorized || refreshedStatus == .provisional || refreshedStatus == .ephemeral else {
            throw NotificationSchedulingError.unauthorized
        }

        let content = createNotificationContent(for: info)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "snooze_\(info.taskId.uuidString)_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        debugLog("🛌 Snoozed notification for task \(info.taskTitle) by \(delayMinutes) minutes")
    }

    // MARK: - Cancel Notifications
    func cancelAllCareTaskNotifications() async {
        if AppLaunchConfiguration.current.disablesRealNotifications {
            await NotificationDebugStore.shared.removeAllPendingNotifications()
            return
        }

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let identifiers = pendingRequests
            .filter { $0.content.userInfo["taskId"] != nil }
            .map(\.identifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        await syncBadgeCount()
        debugLog("Cancelled all care task notifications")
    }

    // MARK: - Badge Management
    func syncBadgeCount() async {
        let token = UUID()
        badgeSyncToken = token
        let deliveredNotifications = await notificationCenter.deliveredNotificationSnapshots()
        guard badgeSyncToken == token else { return }
        let badgeCount = NotificationBadgePolicy.badgeCount(
            for: deliveredNotifications,
            badgeEnabled: settings.badgeEnabled
        )

        notificationCenter.setBadgeCount(badgeCount)
    }

    func clearBadge() {
        badgeSyncToken = UUID()
        notificationCenter.setBadgeCount(0)
    }

    func removeDeliveredCareTaskNotifications(forTaskId taskId: UUID) async {
        let deliveredNotifications = await notificationCenter.deliveredNotificationSnapshots()
        let identifiers = deliveredNotifications
            .filter { $0.taskId == taskId && $0.isTestNotification == false }
            .map(\.identifier)

        guard identifiers.isEmpty == false else { return }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func syncBadgeCountIfNeededOnActivation() async {
        await syncBadgeCount()
    }

    /// Logs only in DEBUG; compiled out of release builds so scheduling/cancel hot paths don't
    /// pay for string interpolation or console I/O in production.
    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }

    // MARK: - Debug Helpers
    func printPendingNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        print("\n=== PENDING NOTIFICATIONS ===")
        print("Total pending: \(pendingRequests.count)")

        for request in pendingRequests.prefix(10) { // Show first 10
            let taskTitle = request.content.userInfo["taskTitle"] as? String ?? "Unknown"
            print("- \(request.identifier): \(taskTitle)")

            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("  Scheduled for: \(trigger.dateComponents)")
            }
        }
        print("===============================\n")
    }

    #if DEBUG
    /// Lets debug-only UI (`SettingsDebugViews.TestNotificationView`) hand a fully-built
    /// ad-hoc `UNNotificationRequest` to the notification center without reaching past
    /// `NotificationManager` — the one direct `UNUserNotificationCenter` call site this repo
    /// allows lives here, not in the view.
    ///
    /// It bypasses `NotificationSchedulingEligibility`, the `badgeNumber` logic, and the settings
    /// gate, so it is compiled into Debug builds only. Its sole caller,
    /// `SettingsDebugViews.TestNotificationView`, is `#if DEBUG` too, so a release build cannot
    /// reach it at all.
    func scheduleDebugNotification(_ request: UNNotificationRequest) async throws {
        try await notificationCenter.add(request)
    }

    /// Delivered notifications for the debug Notification History screen, read through the
    /// injected client so the view never touches `UNUserNotificationCenter` itself.
    func deliveredNotificationsForHistory() async -> [DeliveredNotificationSnapshot] {
        await notificationCenter.deliveredNotificationSnapshots()
    }

    /// Pending ad-hoc test notifications (`userInfo["testNotification"] == true`) for the debug
    /// Notification History screen; care-task reminders and snoozes are left out.
    func pendingTestNotificationRequests() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests().filter { request in
            request.content.userInfo["testNotification"] as? Bool == true
        }
    }
    #endif

    private var badgeNumber: NSNumber? {
        settings.badgeEnabled ? 1 : nil
    }

    private func removeDeliveredNotification(
        withIdentifier identifier: String,
        syncBadgeAfterRemoval: Bool
    ) async {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])

        if syncBadgeAfterRemoval {
            await syncBadgeCount()
        }
    }

    private var presentationOptions: UNNotificationPresentationOptions {
        settings.badgeEnabled ? [.banner, .sound, .badge] : [.banner, .sound]
    }
}

// MARK: - Notification Response Handling
extension NotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler(presentationOptions)

        // Update badge count when notification is presented
        _Concurrency.Task {
            await syncBadgeCount()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Handle test notifications
        if userInfo["testNotification"] as? Bool == true {
            _Concurrency.Task {
                await self.removeDeliveredNotification(
                    withIdentifier: response.notification.request.identifier,
                    syncBadgeAfterRemoval: true
                )
                completionHandler()
            }
            return
        }

        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            completionHandler()
            return
        }

        if let action = NotificationActionCommand(identifier: response.actionIdentifier) {
            _Concurrency.Task {
                _ = await self.actionCoordinator?.handle(action, taskId: taskId)
                completionHandler()
            }
            return
        }

        switch response.actionIdentifier {
        case "RESCHEDULE_ACTION":
            NotificationCenter.default.post(
                name: .rescheduleTask,
                object: nil,
                userInfo: ["taskId": taskId]
            )
            completionHandler()

        case "VIEW_ACTION", UNNotificationDefaultActionIdentifier:
            _Concurrency.Task { @MainActor in
                NavigationRouter.shared.handle(.tasks(taskId: taskId, filter: nil))
                NotificationCenter.default.post(
                    name: .taskNotificationTapped,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
                completionHandler()
            }

        case "EMERGENCY_ACTION":
            NotificationCenter.default.post(
                name: .medicationEmergency,
                object: nil,
                userInfo: ["taskId": taskId]
            )
            completionHandler()

        default:
            debugLog("Unknown notification action: \(response.actionIdentifier)")
            completionHandler()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let taskNotificationTapped = Notification.Name("taskNotificationTapped")
    static let checkOverdueTasks = Notification.Name("checkOverdueTasks")
    static let rescheduleTask = Notification.Name("rescheduleTask")
    static let medicationEmergency = Notification.Name("medicationEmergency")
}

extension EnvironmentValues {
    @Entry var notificationManager: NotificationManager = .shared
}
