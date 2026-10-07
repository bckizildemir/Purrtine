import SwiftUI

struct AppSettingsView: View {
    @Environment(\.notificationManager) private var notificationManager
    @AppStorage(SettingsPreferences.defaultTaskViewKey) private var defaultTaskViewRawValue = SettingsView.TaskViewMode.list.rawValue

    private var defaultTaskView: SettingsView.TaskViewMode {
        SettingsView.TaskViewMode(rawValue: defaultTaskViewRawValue) ?? .list
    }

    private var reminderSummary: NotificationReminderSummaryPresentation {
        NotificationSettingsPresentation.reminderSummary(
            for: notificationManager.settings,
            authorizationStatus: notificationManager.authorizationStatus
        )
    }

    var body: some View {
        SettingsScreen {
            notificationsSection
            taskDisplaySection
            taskAssistantSection
            caregiversSection
        }
        .navigationTitle(String(localized: .settingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }

    private var notificationsSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsNotifications),
                systemImage: "bell.badge.fill",
                tint: tint(for: reminderSummary.tone),
                detail: String(localized: reminderSummary.badgeTextKey),
                accessibilityIdentifier: "settings.notifications.row"
            ) {
                NotificationSettingsView()
            }
        } footer: {
            Text(reminderSummaryDetailText(reminderSummary.detail))
        }
    }

    private var taskDisplaySection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsTaskDisplayTitle),
                systemImage: "list.bullet.rectangle",
                tint: .blue,
                detail: defaultTaskView.displayName
            ) {
                TaskDisplaySettingsView()
            }
        } footer: {
            Text(.settingsTaskDisplayFooter)
        }
    }

    private var taskAssistantSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsTaskAssistantTitle),
                systemImage: "sparkles",
                tint: .purple,
                accessibilityIdentifier: "settings.taskAssistant.row"
            ) {
                TaskAssistantSettingsView()
            }
        } footer: {
            Text(.settingsTaskAssistantFooter)
        }
    }

    private var caregiversSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsCaregivers),
                systemImage: "person.2.fill",
                tint: .teal,
                accessibilityIdentifier: "settings.caregivers.row"
            ) {
                CaregiverManagementView()
            }
        } footer: {
            Text(.settingsCaregiverManagement)
        }
    }

    private func reminderSummaryDetailText(_ detail: NotificationReminderSummaryDetail) -> String {
        switch detail {
        case .enabled:
            return String(localized: .settingsReminderStatusEnabledDetail)
        case .remindersDisabled:
            return String(localized: .settingsReminderStatusDisabledDetail)
        case .permissionRequired:
            return String(localized: .settingsReminderStatusPermissionDetail)
        }
    }

    private func tint(for tone: NotificationPresentationTone) -> Color {
        switch tone {
        case .positive:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .neutral:
            return .accentColor
        }
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .empty) {
        NavigationStack {
            AppSettingsView()
        }
    }
}
#endif
