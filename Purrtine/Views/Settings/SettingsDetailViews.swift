import SwiftUI

struct TaskDisplaySettingsView: View {
    @AppStorage(SettingsPreferences.defaultTaskViewKey) private var defaultTaskViewRawValue = SettingsView.TaskViewMode.list.rawValue
    @AppStorage(SettingsPreferences.showCompletedTasksKey) private var showCompletedTasks = true
    @AppStorage(SettingsPreferences.appearanceModeKey) private var appearanceModeRawValue = AppearanceMode.system.rawValue

    private var defaultTaskViewBinding: Binding<SettingsView.TaskViewMode> {
        Binding(
            get: { SettingsView.TaskViewMode(rawValue: defaultTaskViewRawValue) ?? .list },
            set: { defaultTaskViewRawValue = $0.rawValue }
        )
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { SettingsPreferences.resolvedAppearanceMode(from: appearanceModeRawValue) },
            set: { appearanceModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        SettingsScreen {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(.settingsDefaultTaskView)
                        .foregroundStyle(.primary)

                    Picker(String(localized: .settingsDefaultTaskView), selection: defaultTaskViewBinding) {
                        ForEach(SettingsView.TaskViewMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            } footer: {
                Text(.settingsTaskDisplayFooter)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(.settingsTheme)
                        .foregroundStyle(.primary)

                    Picker(String(localized: .settingsTheme), selection: appearanceBinding) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance.picker")
                }
                .padding(.vertical, 4)
            } footer: {
                Text(.settingsAppearanceFooter)
            }

            Section {
                Toggle(String(localized: .settingsShowCompletedTasks), isOn: $showCompletedTasks)
                    .tint(.accentColor)
            } footer: {
                Text(.settingsCompletedTasksFooter)
            }
        }
        .navigationTitle(String(localized: .settingsTaskDisplayTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TaskAssistantSettingsView: View {
    @AppStorage(SettingsPreferences.taskAssistantCloudConsentGrantedKey) private var isCloudConsentGranted = false

    var body: some View {
        SettingsScreen {
            Section {
                Toggle(String(localized: .settingsTaskAssistantAiToggle), isOn: $isCloudConsentGranted)
                    .tint(.accentColor)
            } footer: {
                Text(.settingsTaskAssistantFooter)
            }
        }
        .navigationTitle(String(localized: .settingsTaskAssistantTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportSettingsView: View {
    var body: some View {
        SettingsScreen {
            Section {
                SettingsAppInfoCard(
                    appName: String(localized: .aboutAppName),
                    versionText: versionText,
                    description: String(localized: .aboutDescription)
                )
            }
            .settingsCardRowStyle()

            Section {
                if let reviewURL = SettingsSupportConfiguration.appStoreReviewURL {
                    SettingsExternalLinkRow(
                        title: String(localized: .settingsRateApp),
                        systemImage: "star.fill",
                        tint: .yellow,
                        url: reviewURL,
                        accessibilityIdentifier: "settings.rateApp"
                    )
                }

                if let contactSupportURL = SettingsSupportConfiguration.contactSupportURL {
                    SettingsExternalLinkRow(
                        title: String(localized: .settingsGiveFeedback),
                        systemImage: "envelope.fill",
                        tint: .blue,
                        url: contactSupportURL,
                        accessibilityIdentifier: "settings.giveFeedback"
                    )
                }

                if let privacyURL = SettingsSupportConfiguration.privacyURL {
                    SettingsExternalLinkRow(
                        title: String(localized: .settingsPrivacyPolicy),
                        systemImage: "hand.raised.fill",
                        tint: .teal,
                        url: privacyURL,
                        accessibilityIdentifier: "settings.privacyPolicy"
                    )
                }

                if let termsURL = SettingsSupportConfiguration.termsURL {
                    SettingsExternalLinkRow(
                        title: String(localized: .settingsTermsOfService),
                        systemImage: "doc.text.fill",
                        tint: .indigo,
                        url: termsURL,
                        accessibilityIdentifier: "settings.termsOfService"
                    )
                }
            } header: {
                Text(.settingsSupportTitle)
            } footer: {
                Text(.settingsSupportFooter)
            }

            Section {
                Text(.aboutDeveloperDescription)
                    .foregroundStyle(.secondary)
            } header: {
                Text(.aboutDeveloper)
            }
        }
        .navigationTitle(String(localized: .settingsSupportTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "--"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"
        return String(localized: .settingsVersionLabel(version, build))
    }
}

#if DEBUG
#Preview("Task Display Settings") {
    PreviewHost(scenario: .empty) {
        NavigationStack {
            TaskDisplaySettingsView()
        }
    }
}
#endif
