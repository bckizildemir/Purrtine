import Foundation
import UserNotifications

enum NotificationPermissionAction: Equatable {
    case none
    case requestPermission
    case openSystemSettings
    case refreshStatus
}

enum NotificationPresentationTone: Equatable {
    case positive
    case warning
    case critical
    case neutral
}

struct NotificationPermissionPresentation: Equatable {
    let statusTextKey: LocalizedStringResource
    let badgeTextKey: LocalizedStringResource
    let actionTitleKey: LocalizedStringResource?
    let action: NotificationPermissionAction
    let tone: NotificationPresentationTone

    var allowsEditing: Bool {
        action == .none
    }
}

enum NotificationReminderSummaryDetail: Equatable {
    case enabled
    case remindersDisabled
    case permissionRequired
}

struct NotificationReminderSummaryPresentation: Equatable {
    let statusTextKey: LocalizedStringResource
    let badgeTextKey: LocalizedStringResource
    let detail: NotificationReminderSummaryDetail
    let tone: NotificationPresentationTone
}

enum NotificationSettingsMonitoringCommand: Equatable {
    case start
    case stop
}

enum NotificationSettingsPresentation {
    static func permissionPresentation(
        for authorizationStatus: UNAuthorizationStatus
    ) -> NotificationPermissionPresentation {
        switch authorizationStatus {
        case .authorized:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusAuthorized,
                badgeTextKey: .notificationSettingsBadgeReady,
                actionTitleKey: nil,
                action: .none,
                tone: .positive
            )
        case .provisional:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusProvisional,
                badgeTextKey: .notificationSettingsBadgeTemporary,
                actionTitleKey: nil,
                action: .none,
                tone: .warning
            )
        case .ephemeral:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusEphemeral,
                badgeTextKey: .notificationSettingsBadgeTemporary,
                actionTitleKey: nil,
                action: .none,
                tone: .warning
            )
        case .notDetermined:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusNotDetermined,
                badgeTextKey: .notificationSettingsBadgePermissionNeeded,
                actionTitleKey: .notificationSettingsButtonAllow,
                action: .requestPermission,
                tone: .warning
            )
        case .denied:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusDenied,
                badgeTextKey: .notificationSettingsBadgePermissionNeeded,
                actionTitleKey: .notificationSettingsButtonOpenSettings,
                action: .openSystemSettings,
                tone: .critical
            )
        @unknown default:
            return NotificationPermissionPresentation(
                statusTextKey: .notificationSettingsStatusUnknown,
                badgeTextKey: .notificationSettingsBadgeCheckStatus,
                actionTitleKey: .notificationSettingsButtonCheck,
                action: .refreshStatus,
                tone: .neutral
            )
        }
    }

    static func reminderSummary(
        for settings: NotificationSettings,
        authorizationStatus: UNAuthorizationStatus
    ) -> NotificationReminderSummaryPresentation {
        let permission = permissionPresentation(for: authorizationStatus)

        guard authorizationStatus.allowsReminderConfiguration else {
            return NotificationReminderSummaryPresentation(
                statusTextKey: permission.statusTextKey,
                badgeTextKey: permission.badgeTextKey,
                detail: .permissionRequired,
                tone: permission.tone
            )
        }

        guard settings.isEnabled else {
            return NotificationReminderSummaryPresentation(
                statusTextKey: .notificationSettingsSummaryDisabledTitle,
                badgeTextKey: .notificationSettingsBadgeOff,
                detail: .remindersDisabled,
                tone: .neutral
            )
        }

        return NotificationReminderSummaryPresentation(
            statusTextKey: .notificationSettingsSummaryEnabledTitle,
            badgeTextKey: permission.badgeTextKey,
            detail: .enabled,
            tone: .positive
        )
    }
}

enum NotificationSettingsApplication {
    static func monitoringCommand(
        for settings: NotificationSettings,
        authorizationStatus: UNAuthorizationStatus
    ) -> NotificationSettingsMonitoringCommand {
        if settings.isEnabled && authorizationStatus.allowsReminderConfiguration {
            return .start
        }

        return .stop
    }
}

extension UNAuthorizationStatus {
    var allowsReminderConfiguration: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
