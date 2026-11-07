import Observation
import SwiftUI

// MARK: - App Tab Enum
enum AppTab: Int, Hashable {
    case home = 0
    case tasks = 1
    case assistant = 2
    case settings = 3
}

struct ContentView: View {
    @Environment(\.navigationRouter) private var navigationRouter
    @Environment(\.haptics) private var haptics

    @State private var hasAppliedLaunchConfiguration = false

    let onboardingManager = OnboardingManager.shared

    var body: some View {
        Group {
            if onboardingManager.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            #if DEBUG
            // DebugDataService.createSampleData(in: ModelContext(...))
            #endif

            if !hasAppliedLaunchConfiguration {
                AppLaunchBootstrapper.applyLaunchStateIfNeeded(to: navigationRouter)
                hasAppliedLaunchConfiguration = true
            }
        }
        .onOpenURL { url in
            if let route = AppRoute(url: url) {
                NavigationRouter.shared.handle(route)
            }
        }
    }

    @ViewBuilder
    private var mainTabView: some View {
        if #available(iOS 26, *) {
            iOS26TabView
        } else {
            legacyTabView
        }
    }

    @ViewBuilder
    @available(iOS 26.0, *)
    private var iOS26TabView: some View {
        @Bindable var router = navigationRouter

        let tabView = TabView(selection: $router.selectedTab) {
            Tab(String(localized: .tabHome), systemImage: "calendar", value: AppTab.home) {
                HomePageView(
                    selectedTab: $router.selectedTab,
                    selectedTaskFilter: $router.selectedTaskFilter
                )
            }

            Tab(
                String(localized: .tabTasks),
                systemImage: router.selectedTab == .tasks ? "checklist.checked" : "checklist",
                value: AppTab.tasks
            ) {
                TaskManagementView(
                    selectedTaskId: $router.selectedTaskId,
                    selectedTaskFilter: $router.selectedTaskFilter
                )
            }

            Tab(
                String(localized: .tabAssistant),
                systemImage: "cat.circle.fill",
                value: AppTab.assistant
            ) {
                TaskAssistantView { taskID in
                    router.handle(.tasks(taskId: taskID))
                }
            }

            Tab(String(localized: .tabMore), systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(
                    shouldNavigateToMyCats: $router.shouldNavigateToMyCats,
                    shouldNavigateToHistory: $router.shouldNavigateToHistory
                )
            }
        }
        .tint(.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                haptics.impact(.light)
            }
        }

        tabView
    }

    private var legacyTabView: some View {
        @Bindable var router = navigationRouter

        return TabView(selection: $router.selectedTab) {
            Tab(String(localized: .tabHome), systemImage: "calendar", value: AppTab.home) {
                HomePageView(
                    selectedTab: $router.selectedTab,
                    selectedTaskFilter: $router.selectedTaskFilter
                )
            }

            Tab(
                String(localized: .tabTasks),
                systemImage: router.selectedTab == .tasks ? "checklist.checked" : "checklist",
                value: AppTab.tasks
            ) {
                TaskManagementView(
                    selectedTaskId: $router.selectedTaskId,
                    selectedTaskFilter: $router.selectedTaskFilter
                )
            }

            Tab(
                String(localized: .tabAssistant),
                systemImage: "cat.circle.fill",
                value: AppTab.assistant
            ) {
                TaskAssistantView { taskID in
                    router.handle(.tasks(taskId: taskID))
                }
            }

            Tab(String(localized: .tabMore), systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(
                    shouldNavigateToMyCats: $router.shouldNavigateToMyCats,
                    shouldNavigateToHistory: $router.shouldNavigateToHistory
                )
            }
        }
        .tint(.blue)
        .onChange(of: router.selectedTab) { _, _ in
            haptics.impact(.light)
        }
    }
}

#Preview {
    ContentView()
}
