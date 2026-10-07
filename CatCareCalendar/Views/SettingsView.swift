import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.navigationRouter) private var navigationRouter
    @Environment(\.modelContext) private var modelContext
    @Binding var shouldNavigateToMyCats: Bool
    @Binding var shouldNavigateToHistory: Bool
    @Query(sort: \Cat.name) private var cats: [Cat]
    @AppStorage(SettingsPreferences.hapticFeedbackEnabledKey) private var enableHapticFeedback = true

    enum TaskViewMode: String, CaseIterable {
        case list = "list"
        case calendar = "calendar"

        var displayName: String {
            switch self {
            case .list:
                return String(localized: .settingsTaskViewList)
            case .calendar:
                return String(localized: .settingsTaskViewCalendar)
            }
        }
    }

    private let shortcutColumns = [
        GridItem(.flexible(minimum: 0), spacing: 12),
        GridItem(.flexible(minimum: 0), spacing: 12)
    ]

    private var weeklyCompletionCount: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        // Count directly in the store instead of faulting every task's completions into memory.
        let descriptor = FetchDescriptor<CareTaskCompletion>(
            predicate: #Predicate { $0.completedAt >= startOfWeek }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var body: some View {
        NavigationStack {
            SettingsScreen {
                shortcutsSection
                settingsMenuSection
                supportSection
                hapticFeedbackSection
                #if DEBUG
                developerSection
                #endif
            }
            .accessibilityIdentifier("settings.view")
            .navigationChromeTitle(
                semanticTitle: String(localized: .tabMore),
                visualTitle: Text(.tabMore)
            )
            .navigationDestination(isPresented: $shouldNavigateToMyCats) {
                CatsTabView()
            }
            .navigationDestination(isPresented: $shouldNavigateToHistory) {
                HistoryView(selectedTab: .constant(.tasks))
            }
        }
    }

    private var shortcutsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: shortcutColumns, spacing: 12) {
                    SettingsMetricCard(
                        title: String(localized: .tabCats),
                        value: "\(cats.count)",
                        systemImage: "cat.circle.fill",
                        accentColor: .pink,
                        accessibilityIdentifier: "settings.shortcut.cats"
                    ) {
                        shouldNavigateToMyCats = true
                    }

                    SettingsMetricCard(
                        title: String(localized: .historyTitle),
                        value: "\(weeklyCompletionCount)",
                        systemImage: "clock.arrow.circlepath",
                        accentColor: .purple,
                        accessibilityIdentifier: "settings.shortcut.history"
                    ) {
                        openHistory()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .settingsCardRowStyle()
    }

    private var settingsMenuSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsTitle),
                systemImage: "gearshape.fill",
                tint: .gray,
                accessibilityIdentifier: "settings.appSettings.row"
            ) {
                AppSettingsView()
            }
        } footer: {
            Text(.settingsAppSettingsSubtitle)
        }
    }

    private var supportSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsSupportTitle),
                systemImage: "lifepreserver",
                tint: .orange,
                accessibilityIdentifier: "settings.support.row"
            ) {
                SupportSettingsView()
            }
        } footer: {
            Text(.settingsSupportFooter)
        }
    }

    private var hapticFeedbackSection: some View {
        Section {
            Toggle(String(localized: .settingsHapticFeedback), isOn: $enableHapticFeedback)
                .tint(.accentColor)
        } footer: {
            Text(.settingsHapticsFooter)
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            SettingsDestinationRow(
                title: String(localized: .settingsDeveloperTools),
                systemImage: "hammer.fill",
                tint: .indigo,
                accessibilityIdentifier: "settings.developerTools"
            ) {
                DeveloperToolsView(enableHapticFeedback: $enableHapticFeedback)
            }
        } footer: {
            Text(.debugDescription)
        }
    }
    #endif

    private func openHistory() {
        navigationRouter.selectedHistoryTaskId = nil
        shouldNavigateToHistory = true
    }

}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        SettingsView(
            shouldNavigateToMyCats: .constant(false),
            shouldNavigateToHistory: .constant(false)
        )
    }
}
#endif
