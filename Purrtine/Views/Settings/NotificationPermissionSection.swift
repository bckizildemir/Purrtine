import SwiftUI
import UserNotifications

/// The permission status card of the notification settings screen.
///
/// This is a `View` struct rather than a computed property on
/// `NotificationSettingsView` for two reasons. The project style guide asks for
/// view structs over computed properties, and this is the expression the type
/// checker cannot render a diagnostic inside once the app target builds with
/// `SWIFT_STRICT_CONCURRENCY = complete`.
/// See `docs/swift6-concurrency-assessment.md`, category F.
struct NotificationPermissionSection: View {
    let presentation: NotificationPermissionPresentation

    /// Runs when the user taps the card's action button.
    let action: () -> Void

    var body: some View {
        Section {
            SettingsInfoCard(
                title: String(localized: .notificationSettingsPermissionTitle),
                message: supportCopy,
                systemImage: "bell.badge.fill",
                tint: tint,
                badgeTitle: String(localized: presentation.badgeTextKey),
                badgeTone: presentation.tone,
                actionTitle: presentation.actionTitleKey.map { String(localized: $0) },
                action: presentation.actionTitleKey == nil ? nil : action
            )
            .accessibilityIdentifier("notificationSettings.permissionCard")
        }
        .settingsCardRowStyle()
    }

    private var supportCopy: String {
        switch presentation.action {
        case .none:
            return String(localized: .notificationSettingsPermissionReadyDetail)
        case .requestPermission:
            return String(localized: .notificationSettingsPermissionRequestDetail)
        case .openSystemSettings:
            return String(localized: .notificationSettingsPermissionDeniedDetail)
        case .refreshStatus:
            return String(localized: .notificationSettingsPermissionRefreshDetail)
        }
    }

    private var tint: Color {
        switch presentation.tone {
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
    SettingsScreen {
        NotificationPermissionSection(
            presentation: NotificationSettingsPresentation.permissionPresentation(for: .denied),
            action: { }
        )
    }
}
#endif
