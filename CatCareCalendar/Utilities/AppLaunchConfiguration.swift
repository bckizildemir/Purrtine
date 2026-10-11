import Foundation

enum UITestSeedScenario: String, CaseIterable, Hashable {
    case singleCat = "single_cat"
    case basicDetails = "basic_details"
    case pendingTask = "pending_task"
    case overdueTask = "overdue_task"
    case historyCompletion = "history_completion"
    case sharedTaskCatDeletion = "shared_task_cat_deletion"
    case longTaskList = "long_task_list"
}

enum UITestLaunchRoute: String, CaseIterable, Equatable {
    case home = "home"
    case tasks = "tasks"
    case assistant = "assistant"
    case settings = "settings"
    case cats = "cats"
    case history = "history"
    case addTask = "add_task"
}

enum UITestNotificationAction: String, CaseIterable, Equatable {
    case complete
    case snooze10 = "snooze_10"

    var command: NotificationActionCommand {
        switch self {
        case .complete:
            return .complete
        case .snooze10:
            return .snooze(minutes: 10)
        }
    }
}

struct UITestNotificationActionSimulation: Equatable {
    let action: UITestNotificationAction
    let scenario: UITestSeedScenario
}

struct AppLaunchConfiguration {
    static let current = AppLaunchConfiguration(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )

    let arguments: [String]
    let environment: [String: String]

    /// Nonisolated so a `@Test(arguments:)` list, which is built outside the main actor, can
    /// construct configurations directly. It only stores two `Sendable` values.
    nonisolated init(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.arguments = arguments
        self.environment = environment
    }

    var isUITesting: Bool { hasArgument("-ui-testing") }
    var isUnitTesting: Bool { environment["CATCARE_UNIT_TESTING"] == "1" }
    var isRunningForPreviews: Bool { environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
    var usesInMemoryStore: Bool { isUITesting || isUnitTesting || isRunningForPreviews }
    var skipsNotificationSetup: Bool {
        isUITesting || isUnitTesting || isRunningForPreviews || hasArgument("-skip-notification-setup")
    }
    var disablesRealNotifications: Bool { isUITesting || isRunningForPreviews }
    #if DEBUG
    /// UI-test-only injection: makes the two care-task notification entry points throw.
    ///
    /// Compiled into Debug builds only, and gated on `isUITesting` on top of that, so a release
    /// build has no such property and cannot reach it even if the argument is passed.
    var failsNotificationSchedule: Bool { isUITesting && hasArgument("-fail-notification-schedule") }
    /// UI-test-only injection: makes the commit in `CatDeletionService.delete` throw, so the UI
    /// tests can reach the "delete not saved yet" alert. Debug builds only, gated like the one above.
    var failsCatDeleteCommit: Bool { isUITesting && hasArgument("-fail-cat-delete-commit") }
    /// UI-test-only: keeps UIKit animations on, which `-ui-testing` otherwise turns off, so a UI test
    /// can reach a race between a closing presentation and the next one (#31). Debug builds only.
    var keepsAnimations: Bool { isUITesting && hasArgument("-keep-animations") }
    #endif
    var disablesCloudServices: Bool { isUITesting || isUnitTesting || isRunningForPreviews }
    var resetsOnboarding: Bool { hasArgument("-reset-onboarding") }
    var completesOnboarding: Bool { hasArgument("-complete-onboarding") }
    var seedsSingleCat: Bool { hasArgument("-seed-single-cat") }
    var seedsSecondCaregiver: Bool { hasArgument("-seed-second-caregiver") }
    var launchRoute: UITestLaunchRoute? { value(for: "-launch-route").flatMap(UITestLaunchRoute.init(rawValue:)) }
    var launchTaskFilter: CareTaskFilter? { value(for: "-launch-task-filter").flatMap(CareTaskFilter.init(rawValue:)) }
    var onboardingStep: OnboardingStep? { value(for: "-onboarding-step").flatMap(OnboardingStep.init(rawValue:)) }
    var simulatedNotificationAction: UITestNotificationActionSimulation? {
        guard let action = value(for: "-simulate-notification-action").flatMap(UITestNotificationAction.init(rawValue:)) else {
            return nil
        }

        let scenario = value(for: "-simulate-notification-scenario")
            .flatMap(UITestSeedScenario.init(rawValue:))
            ?? .pendingTask

        return UITestNotificationActionSimulation(action: action, scenario: scenario)
    }
    var seedScenarios: Set<UITestSeedScenario> {
        var scenarios = Set(values(for: "-seed-scenario").compactMap(UITestSeedScenario.init(rawValue:)))
        if seedsSingleCat {
            scenarios.insert(.singleCat)
        }
        if let simulation = simulatedNotificationAction {
            scenarios.insert(simulation.scenario)
        }
        return scenarios
    }

    func hasArgument(_ argument: String) -> Bool {
        arguments.contains(argument)
    }

    func value(for argument: String) -> String? {
        guard let index = arguments.firstIndex(of: argument) else { return nil }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else { return nil }

        let value = arguments[nextIndex]
        return value.hasPrefix("-") ? nil : value
    }

    func values(for argument: String) -> [String] {
        var collectedValues: [String] = []
        for (index, currentArgument) in arguments.enumerated() where currentArgument == argument {
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex else { continue }

            let value = arguments[valueIndex]
            if value.hasPrefix("-") == false {
                collectedValues.append(value)
            }
        }
        return collectedValues
    }
}
