import SwiftUI

struct AdvancedNotificationSettingsView: View {
    @Environment(\.notificationManager) private var notificationManager
    @Binding var settings: NotificationSettings

    private var overdueReminderDelayBinding: Binding<Int?> {
        Binding(
            get: { settings.overdueReminderDelayMinutes },
            set: { settings.overdueReminderDelayMinutes = $0 }
        )
    }

    var body: some View {
        SettingsScreen {
            generalSettingsSection
            deliverySettingsSection
            categorySettingsSection
        }
        .navigationTitle(String(localized: .notificationSettingsAdvancedTitle))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("advancedNotificationSettings.view")
        .onDisappear {
            notificationManager.applySettings(settings)
        }
    }

    private var generalSettingsSection: some View {
        Section {
            Picker(String(localized: .notificationSettingsOverdueCheck), selection: overdueReminderDelayBinding) {
                Text(String(localized: "notification.settings.overdue.off")).tag(Int?.none)
                Text(String(localized: "notification.settings.overdue.15_minutes")).tag(Int?.some(15))
                Text(String(localized: "notification.settings.overdue.30_minutes")).tag(Int?.some(30))
                Text(String(localized: "notification.settings.overdue.1_hour")).tag(Int?.some(60))
                Text(String(localized: "notification.settings.overdue.2_hours")).tag(Int?.some(120))
                Text(String(localized: "notification.settings.overdue.4_hours")).tag(Int?.some(240))
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("advancedNotificationSettings.overdueReminder")
        } header: {
            Text(.notificationSettingsAdvancedGeneral)
        } footer: {
            Text(.notificationSettingsAdvancedGeneralDescription)
        }
    }

    private var deliverySettingsSection: some View {
        Section {
            Toggle(String(localized: .notificationSettingsSoundEnabled), isOn: $settings.soundEnabled)
                .accessibilityIdentifier("advancedNotificationSettings.soundToggle")
                .accessibilityValue(Text(settings.soundEnabled ? .notificationSettingsStateOn : .notificationSettingsStateOff))

            Toggle(String(localized: .notificationSettingsBadgeEnabled), isOn: $settings.badgeEnabled)

            Toggle(String(localized: .notificationSettingsShowPreview), isOn: $settings.showTaskDetails)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(.notificationSettingsSoundEnabledDetail)
                Text(.notificationSettingsBadgeEnabledDetail)
                Text(.notificationSettingsShowPreviewDetail)
            }
        }
    }

    private var categorySettingsSection: some View {
        Section {
            ForEach(CareTaskCategory.allCases, id: \.self) { category in
                Toggle(category.displayName, isOn: categoryBinding(for: category))
                    .accessibilityIdentifier("advancedNotificationSettings.category.\(category.rawValue)")
            }
        } header: {
            Text(.notificationSettingsCategorySection)
        } footer: {
            Text(.notificationSettingsCategoryDescription)
        }
    }

    private func categoryBinding(for category: CareTaskCategory) -> Binding<Bool> {
        Binding(
            get: { settings.enabledCategories.contains(category) },
            set: { isEnabled in
                if isEnabled {
                    settings.enabledCategories.insert(category)
                } else {
                    settings.enabledCategories.remove(category)
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .empty) {
        NavigationStack {
            AdvancedNotificationSettingsView(settings: .constant(.default))
        }
    }
}
#endif
