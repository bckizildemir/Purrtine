import Testing
import UserNotifications
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationSettingsPresentationTests {
    @Test(arguments: [
        (
            UNAuthorizationStatus.authorized,
            NotificationPermissionAction.none,
            "notification.settings.status.authorized",
            "notification.settings.badge.ready",
            true
        ),
        (
            UNAuthorizationStatus.notDetermined,
            NotificationPermissionAction.requestPermission,
            "notification.settings.status.not_determined",
            "notification.settings.badge.permission_needed",
            false
        ),
        (
            UNAuthorizationStatus.denied,
            NotificationPermissionAction.openSystemSettings,
            "notification.settings.status.denied",
            "notification.settings.badge.permission_needed",
            false
        )
    ])
    func permissionPresentationMapsAuthorizationState(
        status: UNAuthorizationStatus,
        expectedAction: NotificationPermissionAction,
        expectedStatusKey: String,
        expectedBadgeKey: String,
        expectedAllowsEditing: Bool
    ) {
        let presentation = NotificationSettingsPresentation.permissionPresentation(for: status)

        #expect(presentation.action == expectedAction)
        #expect(presentation.statusTextKey.key == expectedStatusKey)
        #expect(presentation.badgeTextKey.key == expectedBadgeKey)
        #expect(presentation.allowsEditing == expectedAllowsEditing)
    }

    @Test
    func reminderSummaryShowsEnabledStateWhenRemindersAreEnabled() {
        let settings = NotificationSettings.default

        let summary = NotificationSettingsPresentation.reminderSummary(
            for: settings,
            authorizationStatus: .authorized
        )

        #expect(summary.statusTextKey.key == "notification.settings.summary.enabled_title")
        #expect(summary.badgeTextKey.key == "notification.settings.badge.ready")
        #expect(summary.detail == .enabled)
        #expect(summary.tone == .positive)
    }

    @Test
    func reminderSummaryShowsDisabledStateWhenSettingsAreOff() {
        var settings = NotificationSettings.default
        settings.isEnabled = false

        let summary = NotificationSettingsPresentation.reminderSummary(
            for: settings,
            authorizationStatus: .authorized
        )

        #expect(summary.statusTextKey.key == "notification.settings.summary.disabled_title")
        #expect(summary.badgeTextKey.key == "notification.settings.badge.off")
        #expect(summary.detail == .remindersDisabled)
        #expect(summary.tone == .neutral)
    }

    @Test
    func reminderSummaryRequiresPermissionWhenAuthorizationDoesNotAllowScheduling() {
        let summary = NotificationSettingsPresentation.reminderSummary(
            for: .default,
            authorizationStatus: .denied
        )

        #expect(summary.statusTextKey.key == "notification.settings.status.denied")
        #expect(summary.badgeTextKey.key == "notification.settings.badge.permission_needed")
        #expect(summary.detail == .permissionRequired)
        #expect(summary.tone == .critical)
    }

    @Test(arguments: [
        (true, UNAuthorizationStatus.authorized, NotificationSettingsMonitoringCommand.start),
        (true, UNAuthorizationStatus.provisional, NotificationSettingsMonitoringCommand.start),
        (true, UNAuthorizationStatus.denied, NotificationSettingsMonitoringCommand.stop),
        (false, UNAuthorizationStatus.authorized, NotificationSettingsMonitoringCommand.stop)
    ])
    func monitoringCommandMatchesSettingsAndAuthorization(
        isEnabled: Bool,
        authorizationStatus: UNAuthorizationStatus,
        expectedCommand: NotificationSettingsMonitoringCommand
    ) {
        var settings = NotificationSettings.default
        settings.isEnabled = isEnabled

        let command = NotificationSettingsApplication.monitoringCommand(
            for: settings,
            authorizationStatus: authorizationStatus
        )

        #expect(command == expectedCommand)
    }
}
