import SwiftUI
import SwiftData
import UserNotifications

#if DEBUG
struct DeveloperToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.notificationManager) private var notificationManager
    @Binding var enableHapticFeedback: Bool

    var body: some View {
        SettingsScreen {
            Section {
                SettingsButtonRow(
                    title: String(localized: .debugCreateSampleData),
                    systemImage: "wand.and.stars",
                    tint: .purple
                ) {
                    Task {
                        await DebugDataService.createSampleData(in: modelContext, taskWriter: careTaskWriter)
                        triggerHaptic(.medium)
                    }
                }

                SettingsButtonRow(
                    title: String(localized: .debugClearSampleData),
                    systemImage: "trash.circle.fill",
                    tint: .red,
                    role: .destructive
                ) {
                    Task {
                        await DebugDataService.clearSampleData(in: modelContext, taskWriter: careTaskWriter)
                        triggerHaptic(.heavy)
                    }
                }

                SettingsButtonRow(
                    title: String(localized: .debugCreateOverdueTasks),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                ) {
                    Task {
                        await DebugDataService.createOverdueTasks(in: modelContext, taskWriter: careTaskWriter)
                        triggerHaptic(.light)
                    }
                }

                SettingsButtonRow(
                    title: String(localized: .debugResetOnboarding),
                    systemImage: "arrow.clockwise",
                    tint: .blue
                ) {
                    OnboardingManager.shared.resetOnboarding()
                    triggerHaptic(.medium)
                }
            } header: {
                Text(.debugSectionTitle)
            } footer: {
                Text(.debugDescription)
            }

            Section {
                SettingsDestinationRow(
                    title: String(localized: .notificationSettingsHistory),
                    systemImage: "clock.arrow.circlepath",
                    tint: .indigo,
                    accessibilityIdentifier: "developerTools.notificationHistory"
                ) {
                    NotificationHistoryView()
                }

                SettingsDestinationRow(
                    title: String(localized: .notificationSettingsSendTest),
                    systemImage: "bell.badge",
                    tint: .orange
                ) {
                    TestNotificationView()
                }

                SettingsButtonRow(
                    title: String(localized: .notificationSettingsClearAll),
                    systemImage: "bell.slash.fill",
                    tint: .red,
                    role: .destructive
                ) {
                    clearAllNotifications()
                }
            } header: {
                Text(.notificationSettingsTestingSection)
            }
        }
        .navigationTitle(String(localized: .settingsDeveloperTools))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let hapticsService = DefaultHapticsService()
        hapticsService.impact(style)
    }

    private func clearAllNotifications() {
        _Concurrency.Task {
            await notificationManager.cancelAllCareTaskNotifications()
        }
    }
}

struct NotificationHistoryView: View {
    @Environment(\.notificationManager) private var notificationManager
    @State private var deliveredNotifications: [DeliveredNotificationSnapshot] = []
    @State private var pendingTestNotifications: [UNNotificationRequest] = []
    @State private var pendingTaskNotifications: [DebugPendingNotification] = []

    var body: some View {
        List {
            #if DEBUG
            if pendingTaskNotifications.isEmpty == false {
                Section("Task Notifications (Pending)") {
                    ForEach(pendingTaskNotifications) { notification in
                        NotificationHistoryRow(
                            title: notification.taskTitle,
                            body: notification.body,
                            date: notification.scheduledDate,
                            isTestNotification: true,
                            isPending: true,
                            combinesAccessibilityChildren: false,
                            accessibilityIdentifier: "notificationHistory.pending.\(notification.taskTitle)"
                        )
                    }
                }
            }

            if pendingTestNotifications.isEmpty == false {
                Section("Test Notifications (Pending)") {
                    ForEach(pendingTestNotifications.indices, id: \.self) { index in
                        let request = pendingTestNotifications[index]
                        NotificationHistoryRow(
                            title: request.content.title,
                            body: request.content.body,
                            date: Date(),
                            isTestNotification: true,
                            isPending: true
                        )
                    }
                }
            }
            #endif

            Section(
                deliveredNotifications.isEmpty
                    ? "Delivered Notifications"
                    : "Delivered Notifications (\(deliveredNotifications.count))"
            ) {
                if deliveredNotifications.isEmpty {
                    ContentUnavailableView(
                        String(localized: .notificationHistoryEmptyTitle),
                        systemImage: "bell.slash",
                        description: Text(.notificationHistoryEmptyDescription)
                    )
                } else {
                    ForEach(deliveredNotifications) { delivered in
                        NotificationHistoryRow(
                            title: delivered.title,
                            body: delivered.body,
                            date: delivered.date,
                            isTestNotification: false
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: .notificationHistoryTitle))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationHistory.view")
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        await loadDeliveredNotifications()

        #if DEBUG
        await loadPendingTaskNotifications()
        await loadPendingTestNotifications()
        #endif
    }

    private func loadDeliveredNotifications() async {
        deliveredNotifications = await notificationManager.deliveredNotificationsForHistory()
    }

    #if DEBUG
    private func loadPendingTaskNotifications() async {
        let notifications = await NotificationDebugStore.shared.pendingNotificationSnapshots()

        await MainActor.run {
            pendingTaskNotifications = notifications
        }
    }

    private func loadPendingTestNotifications() async {
        pendingTestNotifications = await notificationManager.pendingTestNotificationRequests()
    }
    #endif
}

struct NotificationHistoryRow: View {
    let title: String?
    let message: String?
    let date: Date?
    let isTestNotification: Bool
    let isPending: Bool
    let combinesAccessibilityChildren: Bool
    let accessibilityIdentifier: String?

    init(
        title: String,
        body: String,
        date: Date,
        isTestNotification: Bool = true,
        isPending: Bool = false,
        combinesAccessibilityChildren: Bool = true,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.message = body
        self.date = date
        self.isTestNotification = isTestNotification
        self.isPending = isPending
        self.combinesAccessibilityChildren = combinesAccessibilityChildren
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                if isTestNotification {
                    SettingsInfoBadge(
                        title: isPending ? "Pending" : "Test",
                        tone: isPending ? .warning : .neutral
                    )
                }
            }

            Text(displayBody)
                .foregroundStyle(.secondary)

            Text(displayDate.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: combinesAccessibilityChildren ? .combine : .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private var displayTitle: String {
        title ?? "Unknown Notification"
    }

    private var displayBody: String {
        message ?? ""
    }

    private var displayDate: Date {
        date ?? Date()
    }
}

struct TestNotificationView: View {
    @Environment(\.notificationManager) private var notificationManager
    @State private var testTitle = String(localized: .notificationTestTitle)
    @State private var testMessage = String(localized: .notificationTestMessage)
    @State private var delaySeconds: Double = 5

    var body: some View {
        SettingsScreen {
            Section(String(localized: .notificationTestSectionTitle)) {
                TextField(String(localized: .notificationTestTitlePlaceholder), text: $testTitle)

                TextField(String(localized: .notificationTestMessagePlaceholder), text: $testMessage, axis: .vertical)
                    .lineLimit(2...4)

                LabeledContent(String(localized: .notificationTestDelayLabel)) {
                    Text(String(localized: .notificationTestDelayValue(Int32(Int(delaySeconds)))))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $delaySeconds, in: 1...60, step: 1)
                    .tint(.accentColor)
            }

            Section {
                Button(String(localized: .debugSendTestNotification)) {
                    sendTestNotification()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(String(localized: .notificationTestNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendTestNotification() {
        _Concurrency.Task {
            await scheduleTestNotification()
        }
    }

    private func scheduleTestNotification() async {
        await notificationManager.checkAuthorizationStatus()

        guard notificationManager.authorizationStatus == .authorized else {
            print("❌ Notification permission not granted (status: \(notificationManager.authorizationStatus.rawValue))")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = testTitle
        content.body = testMessage
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "TEST_NOTIFICATION"
        content.userInfo = [
            "testNotification": true,
            "scheduledAt": Date().timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delaySeconds, 1.0),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationManager.scheduleDebugNotification(request)
            await notificationManager.syncBadgeCount()
        } catch {
            print("❌ Failed to schedule test notification: \(error)")
        }
    }
}
#endif
