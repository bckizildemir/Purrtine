import SwiftUI

/// The main enable / critical-only toggles of the notification settings screen.
///
/// This is a `View` struct rather than a computed property on
/// `NotificationSettingsView` for two reasons. The project style guide asks for
/// view structs over computed properties, and the combined `Section` expression
/// defeats the type checker's diagnostic renderer once the app target builds
/// with `SWIFT_STRICT_CONCURRENCY = complete`.
/// See `docs/swift6-concurrency-assessment.md`, category F.
struct NotificationTogglesSection: View {
    @Binding var settings: NotificationSettings

    /// Whether the permission state lets the user change these toggles.
    let allowsEditing: Bool

    var body: some View {
        Section {
            Toggle(isOn: $settings.isEnabled) {
                SettingsRowLabel(
                    title: String(localized: .notificationSettingsEnableToggle),
                    systemImage: "bell",
                    tint: .orange
                )
            }
            .disabled(allowsEditing == false)
            .tint(.accentColor)

            if settings.isEnabled {
                Toggle(isOn: $settings.criticalTasksOnly) {
                    SettingsRowLabel(
                        title: String(localized: .notificationSettingsCriticalOnly),
                        subtitle: String(localized: .notificationSettingsCriticalOnlyDetail),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                }
                .disabled(allowsEditing == false)
                .tint(.accentColor)
            }
        } header: {
            Text(.notificationSettingsMainSection)
        } footer: {
            Text(footer)
        }
    }

    private var toggleSubtitle: String {
        if allowsEditing {
            return String(localized: .notificationSettingsEnableToggleDetail)
        }

        return String(localized: .notificationSettingsPermissionRequiredDetail)
    }

    private var footer: String {
        if allowsEditing {
            return String(localized: .notificationSettingsMainDescription)
        }

        return toggleSubtitle
    }
}

#if DEBUG
#Preview("Editable") {
    @Previewable @State var settings = NotificationSettings.default

    SettingsScreen {
        NotificationTogglesSection(settings: $settings, allowsEditing: true)
    }
}

#Preview("Permission required") {
    @Previewable @State var settings = NotificationSettings.default

    SettingsScreen {
        NotificationTogglesSection(settings: $settings, allowsEditing: false)
    }
}
#endif
