import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.notificationManager) private var notificationManager

    @State private var settings = NotificationSettings.default
    @State private var hasLoadedSettings = false
    @State private var showingPermissionAlert = false

    private var permissionPresentation: NotificationPermissionPresentation {
        NotificationSettingsPresentation.permissionPresentation(
            for: notificationManager.authorizationStatus
        )
    }

    var body: some View {
        SettingsScreen {
            if notificationManager.authorizationStatus != .authorized {
                NotificationPermissionSection(
                    presentation: permissionPresentation,
                    action: handlePermissionAction
                )
            }
            NotificationTogglesSection(
                settings: $settings,
                allowsEditing: permissionPresentation.allowsEditing
            )
            advancedSection
        }
        .navigationTitle(String(localized: .notificationSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationSettings.view")
        .alert(String(localized: .notificationSettingsAlertTitle), isPresented: $showingPermissionAlert) {
            Button(String(localized: .notificationSettingsAlertOpenSettings)) {
                openAppSettings()
            }
            Button(String(localized: .actionCancel), role: .cancel) { }
        } message: {
            Text(.notificationSettingsAlertMessage)
        }
        .task {
            if hasLoadedSettings == false {
                settings = notificationManager.settings
                hasLoadedSettings = true
            }

            await notificationManager.checkAuthorizationStatus()
        }
        .onChange(of: settings) { _, newValue in
            guard hasLoadedSettings else { return }
            notificationManager.applySettings(newValue)
        }
    }

    private var advancedSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .notificationSettingsAdvancedTitle),
                systemImage: "slider.horizontal.3",
                tint: .indigo,
                accessibilityIdentifier: "notificationSettings.advanced"
            ) {
                AdvancedNotificationSettingsView(settings: $settings)
            }
        } header: {
            Text(.notificationSettingsAdvancedSection)
        } footer: {
            Text(.notificationSettingsAdvancedSummary)
        }
    }

    private func handlePermissionAction() {
        switch permissionPresentation.action {
        case .requestPermission:
            _Concurrency.Task {
                await requestPermission()
            }
        case .openSystemSettings:
            showingPermissionAlert = true
        case .refreshStatus:
            _Concurrency.Task {
                await notificationManager.checkAuthorizationStatus()
            }
        case .none:
            break
        }
    }

    private func requestPermission() async {
        let granted = await notificationManager.requestPermission()
        if granted == false {
            await MainActor.run {
                showingPermissionAlert = true
            }
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .empty) {
        NavigationStack {
            NotificationSettingsView()
        }
    }
}
#endif
