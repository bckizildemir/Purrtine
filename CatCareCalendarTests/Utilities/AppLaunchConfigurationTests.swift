import Testing
@testable import CatCareCalendar

@MainActor
struct AppLaunchConfigurationTests {
    @Test(arguments: [
        (["app", "-ui-testing", "-launch-route", "tasks"], UITestLaunchRoute.tasks),
        (["app", "-ui-testing", "-launch-route", "assistant"], UITestLaunchRoute.assistant),
        (["app", "-ui-testing", "-launch-route", "settings"], UITestLaunchRoute.settings),
        (["app", "-ui-testing", "-launch-route", "history"], UITestLaunchRoute.history),
        (["app", "-ui-testing", "-launch-route", "add_task"], UITestLaunchRoute.addTask)
    ])
    func parsesLaunchRoute(arguments: [String], expectedRoute: UITestLaunchRoute) {
        let configuration = AppLaunchConfiguration(arguments: arguments)

        #expect(configuration.launchRoute == expectedRoute)
    }

    /// `-keep-animations` counts only under `-ui-testing`, like the other UI-test injections (#31).
    @Test(arguments: [
        (["app", "-ui-testing", "-keep-animations"], true),
        (["app", "-ui-testing"], false),
        (["app", "-keep-animations"], false)
    ])
    func keepsAnimationsOnlyWhenAskedUnderUITesting(arguments: [String], expected: Bool) {
        #expect(AppLaunchConfiguration(arguments: arguments).keepsAnimations == expected)
    }

    @Test
    func parsesTaskFilterAndOnboardingStep() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "app",
                "-ui-testing",
                "-launch-task-filter", "overdue",
                "-onboarding-step", "taskSetup"
            ]
        )

        #expect(configuration.launchTaskFilter == .overdue)
        #expect(configuration.onboardingStep == .taskSetup)
    }

    @Test
    func combinesExplicitAndLegacySeedScenarios() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "app",
                "-ui-testing",
                "-seed-single-cat",
                "-seed-scenario", "pending_task",
                "-seed-scenario", "history_completion"
            ]
        )

        #expect(configuration.seedScenarios == [.singleCat, .pendingTask, .historyCompletion])
    }

    @Test
    func parsesSimulatedNotificationActionAndAutoSeedsScenario() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "app",
                "-ui-testing",
                "-simulate-notification-action", "snooze_10",
                "-simulate-notification-scenario", "overdue_task"
            ]
        )

        #expect(configuration.simulatedNotificationAction?.action == .snooze10)
        #expect(configuration.simulatedNotificationAction?.scenario == .overdueTask)
        #expect(configuration.seedScenarios.contains(.overdueTask))
    }

    @Test
    func previewEnvironmentUsesIsolatedRuntimeServices() {
        let configuration = AppLaunchConfiguration(
            arguments: ["app"],
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )

        #expect(configuration.isRunningForPreviews)
        #expect(configuration.usesInMemoryStore)
        #expect(configuration.skipsNotificationSetup)
        #expect(configuration.disablesRealNotifications)
        #expect(configuration.isUITesting == false)
    }

    @Test
    func unitTestEnvironmentUsesIsolatedRuntimeServices() {
        let configuration = AppLaunchConfiguration(
            arguments: ["app"],
            environment: ["CATCARE_UNIT_TESTING": "1"]
        )

        #expect(configuration.isUnitTesting)
        #expect(configuration.usesInMemoryStore)
        #expect(configuration.skipsNotificationSetup)
        #expect(configuration.disablesRealNotifications == false)
        #expect(configuration.disablesCloudServices)
        #expect(configuration.isUITesting == false)
    }
}
