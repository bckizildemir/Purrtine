import SwiftData
import UIKit

enum AppLaunchBootstrapper {
    struct UITestSeedPlan: Equatable {
        let requiresSeedCat: Bool
        let taskFixtures: [UITestTaskFixture]
    }

    struct UITestTaskFixture: Equatable {
        let scenario: UITestSeedScenario
        let title: String
        let category: CareTaskCategory
        let scheduledDate: Date
        /// When set, the seeded schedule carries this time-of-day so
        /// `CareTaskSchedule.effectiveDueDate` resolves to it instead of expanding a
        /// date-only schedule to end-of-day. Leave nil to keep the legacy date-only
        /// (end-of-day) resolution.
        let scheduledTime: Date?
        let status: CareTaskStatus
        let isScheduleActive: Bool
        let createsCompletion: Bool
        let completionNotes: String?
    }

    private static let onboardingKey = "hasCompletedOnboarding"
    private static let uiTestCatName = "UI Test Cat"
    private static let uiTestBasicDetailsCatName = "UI Basic Details Cat"
    private static let uiTestSecondCatName = "UI Second Test Cat"
    static let uiTestSecondCaregiverName = "UI Test Caregiver"
    private static let pendingTaskTitle = "UI Test Task"
    private static let overdueTaskTitle = "UI Test Overdue Task"
    private static let completedTaskTitle = "UI Test Completed Task"
    private static let sharedTaskTitle = "UI Shared Task"
    private static let soloTaskTitle = "UI Solo Task"

    /// Main-actor isolated: it calls `UIView.setAnimationsEnabled` and touches
    /// `OnboardingManager.shared`. The only caller is `App.init()`, which the
    /// `App` protocol already isolates to the main actor.
    @MainActor
    static func prepareProcessState(using configuration: AppLaunchConfiguration = .current) {
        guard configuration.isUITesting else { return }

        #if DEBUG
        if configuration.keepsAnimations == false {
            UIView.setAnimationsEnabled(false)
        }
        #else
        UIView.setAnimationsEnabled(false)
        #endif

        let defaults = UserDefaults.standard
        let onboardingManager = OnboardingManager.shared
        if configuration.resetsOnboarding {
            defaults.set(false, forKey: onboardingKey)
            onboardingManager.resetOnboarding()
        }
        if configuration.completesOnboarding {
            defaults.set(true, forKey: onboardingKey)
            onboardingManager.completeOnboarding()
        }
        if let onboardingStep = configuration.onboardingStep {
            onboardingManager.currentStep = onboardingStep
        }
    }

    static func makeModelContainer(
        using configuration: AppLaunchConfiguration = .current
    ) throws -> ModelContainer {
        // The model list lives in `CatCareSchemaV1` so the store layout is a named,
        // testable version instead of an inline argument list. `SchemaBaselineTests`
        // proves a store written under this schema reopens through the plan intact.
        let schema = CatCareSchemaV1.schema

        if configuration.usesInMemoryStore {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: schema,
                migrationPlan: CatCareMigrationPlan.self,
                configurations: modelConfiguration
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: CatCareMigrationPlan.self
        )
    }

    static func seedInitialDataIfNeeded(
        in context: ModelContext,
        using configuration: AppLaunchConfiguration = .current
    ) {
        guard configuration.isUITesting else { return }
        let plan = seedPlan(for: configuration.seedScenarios)
        guard plan.requiresSeedCat || plan.taskFixtures.isEmpty == false else { return }

        let standardCatScenarios: Set<UITestSeedScenario> = [
            .singleCat,
            .pendingTask,
            .overdueTask,
            .historyCompletion,
            .sharedTaskCatDeletion,
            .longTaskList
        ]
        let needsStandardCat = configuration.seedScenarios
            .intersection(standardCatScenarios)
            .isEmpty == false
        let cat: Cat?
        if needsStandardCat {
            cat = seedSingleCatIfNeeded(in: context)
        } else if configuration.seedScenarios.contains(.basicDetails) {
            cat = seedBasicDetailsCatIfNeeded(in: context)
        } else {
            cat = nil
        }

        if needsStandardCat && configuration.seedScenarios.contains(.basicDetails) {
            seedBasicDetailsCatIfNeeded(in: context)
        }
        let caregiver = defaultCaregiver(in: context)

        if configuration.seedsSecondCaregiver {
            seedSecondCaregiverIfNeeded(in: context)
        }

        if let cat, let caregiver {
            if configuration.seedScenarios.contains(.sharedTaskCatDeletion) {
                seedSharedTaskCatDeletionScenarioIfNeeded(
                    in: context,
                    primaryCat: cat,
                    caregiver: caregiver
                )
            }

            for fixture in plan.taskFixtures {
                seedTaskFixtureIfNeeded(in: context, fixture: fixture, cat: cat, caregiver: caregiver)
            }
        }

        do {
            try context.save()
            #if DEBUG
            print("[UITestSeed] Seeded scenarios: \(configuration.seedScenarios.map(\.rawValue).sorted())")
            #endif
        } catch {
            print("[UITestSeed] Failed to save seeded data: \(error)")
        }
    }

    static func seedPlan(
        for scenarios: Set<UITestSeedScenario>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UITestSeedPlan {
        let requiresSeedCat = scenarios.intersection([
            .singleCat,
            .basicDetails,
            .pendingTask,
            .overdueTask,
            .historyCompletion,
            .sharedTaskCatDeletion,
            .longTaskList
        ]).isEmpty == false
        let startOfToday = calendar.startOfDay(for: now)
        var taskFixtures: [UITestTaskFixture] = []

        if scenarios.contains(.pendingTask) {
            // The pending fixture must land in the `.today` bucket AND stay in the
            // future (pending, not overdue). Plain `now + 2h` crossed midnight when the
            // suite ran after ~22:00; combined with a date-only schedule expanding to
            // end-of-day via `effectiveDueDate`, the task bucketed as `.tomorrow` and
            // dropped off Home + the assistant's due-today quick actions.
            //
            // Clamp the due datetime to end-of-today so it can never spill into
            // tomorrow, and carry it as an explicit `scheduledTime` so the schedule
            // resolves to this exact instant rather than 23:59:59 of the next day.
            // At any wall-clock time `endOfToday >= now`, so the task stays today and
            // non-overdue whether the suite runs at 09:00 or 23:59.
            let endOfToday = calendar.date(
                byAdding: DateComponents(day: 1, second: -1),
                to: startOfToday
            ) ?? now
            let pendingDue = min(calendar.date(byAdding: .hour, value: 2, to: now) ?? now, endOfToday)
            taskFixtures.append(
                UITestTaskFixture(
                    scenario: .pendingTask,
                    title: pendingTaskTitle,
                    category: .feeding,
                    scheduledDate: pendingDue,
                    scheduledTime: pendingDue,
                    status: .pending,
                    isScheduleActive: true,
                    createsCompletion: false,
                    completionNotes: nil
                )
            )
        }

        if scenarios.contains(.overdueTask) {
            taskFixtures.append(
                UITestTaskFixture(
                    scenario: .overdueTask,
                    title: overdueTaskTitle,
                    category: .medication,
                    scheduledDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                    scheduledTime: nil,
                    status: .pending,
                    isScheduleActive: true,
                    createsCompletion: false,
                    completionNotes: nil
                )
            )
        }

        if scenarios.contains(.historyCompletion) {
            taskFixtures.append(
                UITestTaskFixture(
                    scenario: .historyCompletion,
                    title: completedTaskTitle,
                    category: .water,
                    scheduledDate: calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now,
                    scheduledTime: nil,
                    status: .completed,
                    isScheduleActive: false,
                    createsCompletion: true,
                    completionNotes: "UI seeded completion"
                )
            )
        }

        if scenarios.contains(.longTaskList) {
            // Anchor to a fixed time-of-day (rather than `now`) so the 15-minute-per-task
            // stagger can never cross midnight into the next day regardless of when the
            // test suite happens to run.
            let longTaskListBase = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? startOfToday
            for taskNumber in 1...18 {
                let taskNumberText = taskNumber < 10 ? "0\(taskNumber)" : "\(taskNumber)"
                taskFixtures.append(
                    UITestTaskFixture(
                        scenario: .longTaskList,
                        title: "UI Test Long Task \(taskNumberText)",
                        category: .general,
                        scheduledDate: calendar.date(
                            byAdding: .minute,
                            value: taskNumber * 15,
                            to: longTaskListBase
                        ) ?? longTaskListBase,
                        scheduledTime: nil,
                        status: .pending,
                        isScheduleActive: true,
                        createsCompletion: false,
                        completionNotes: nil
                    )
                )
            }
        }

        return UITestSeedPlan(requiresSeedCat: requiresSeedCat, taskFixtures: taskFixtures)
    }

    static func performSimulatedNotificationActionIfNeeded(
        using configuration: AppLaunchConfiguration = .current,
        modelContainer: ModelContainer,
        coordinator: NotificationActionCoordinator
    ) async {
        guard configuration.isUITesting,
              let simulation = configuration.simulatedNotificationAction else {
            return
        }

        guard let taskTitle = fixtureTitle(for: simulation.scenario) else {
            print("[UITestNotification] Scenario \(simulation.scenario.rawValue) does not map to a task fixture")
            return
        }

        let context = ModelContext(modelContainer)

        guard let task = findTask(named: taskTitle, in: context) else {
            print("[UITestNotification] Missing task fixture for scenario \(simulation.scenario.rawValue)")
            return
        }

        let result = await coordinator.handle(simulation.action.command, taskId: task.id)
        if result.didPerformAction == false {
            print("[UITestNotification] Failed to apply simulated action \(simulation.action.rawValue)")
        }
    }

    /// Main-actor isolated: it drives `NavigationRouter`, which is. Its only
    /// caller is a SwiftUI `onAppear`.
    @MainActor
    static func applyLaunchStateIfNeeded(
        to router: NavigationRouter,
        using configuration: AppLaunchConfiguration = .current
    ) {
        guard configuration.isUITesting else { return }

        router.reset()

        switch configuration.launchRoute {
        case .home, .none:
            if let filter = configuration.launchTaskFilter {
                router.handle(.tasks(taskId: nil, filter: filter))
            }
        case .tasks:
            router.handle(.tasks(taskId: nil, filter: configuration.launchTaskFilter))
        case .assistant:
            router.handle(.assistant)
        case .settings:
            router.handle(.settings)
        case .cats:
            router.handle(.cats)
        case .history:
            router.handle(.history())
        case .addTask:
            router.handle(.tasks(taskId: nil, filter: configuration.launchTaskFilter))
            router.shouldTriggerAddTask = true
        }
    }

    @discardableResult
    private static func seedSingleCatIfNeeded(in context: ModelContext) -> Cat {
        let existingCats = cats(in: context)
        if let existingCat = existingCats.first(where: { $0.name == uiTestCatName }) ?? existingCats.first {
            return existingCat
        }

        let cat = Cat(name: uiTestCatName, gender: .unknown)
        context.insert(cat)
        return cat
    }

    @discardableResult
    private static func seedBasicDetailsCatIfNeeded(in context: ModelContext) -> Cat {
        let existingCats = cats(in: context)
        if let existingCat = existingCats.first(where: { $0.name == uiTestBasicDetailsCatName }) {
            return existingCat
        }

        let cat = Cat(
            name: uiTestBasicDetailsCatName,
            photoURLs: ["ui-test-photo-marker"],
            age: 48,
            gender: .female
        )
        context.insert(cat)
        return cat
    }

    private static func seedTaskFixtureIfNeeded(
        in context: ModelContext,
        fixture: UITestTaskFixture,
        cat: Cat,
        caregiver: Caregiver
    ) {
        guard findTask(named: fixture.title, in: context) == nil else { return }

        let task = makeTask(
            title: fixture.title,
            scheduledDate: fixture.scheduledDate,
            category: fixture.category,
            cats: [cat],
            caregiver: caregiver
        )

        guard let schedule = task.schedules.first else { return }
        schedule.isActive = fixture.isScheduleActive
        schedule.scheduledTime = fixture.scheduledTime
        task.status = fixture.status

        if fixture.createsCompletion {
            let completion = CareTaskCompletion(
                completedAt: Date(),
                completedForDate: fixture.scheduledDate,
                notes: fixture.completionNotes,
                wasOnTime: true
            )
            completion.task = task
            completion.cats = [cat]
            completion.caregiver = caregiver
            task.completions = [completion]
            context.insert(completion)
        }

        context.insert(task)
        context.insert(schedule)
    }

    private static func makeTask(
        title: String,
        scheduledDate: Date,
        category: CareTaskCategory,
        cats: [Cat],
        caregiver: Caregiver
    ) -> CareTask {
        let task = CareTask(
            title: title,
            description: "Seeded for UI testing",
            category: category,
            iconName: category.iconName,
            priority: .medium,
            status: .pending
        )

        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .once,
            reminderMinutes: 15
        )

        task.assignedCats = cats
        task.assignedCaregiver = caregiver
        schedule.task = task
        task.schedules = [schedule]
        return task
    }

    private static func seedSharedTaskCatDeletionScenarioIfNeeded(
        in context: ModelContext,
        primaryCat: Cat,
        caregiver: Caregiver
    ) {
        let secondCat = secondTestCatIfNeeded(in: context)

        if findTask(named: sharedTaskTitle, in: context) == nil {
            let sharedTask = makeTask(
                title: sharedTaskTitle,
                scheduledDate: Date().addingTimeInterval(2 * 60 * 60),
                category: .feeding,
                cats: [primaryCat, secondCat],
                caregiver: caregiver
            )
            context.insert(sharedTask)
            if let schedule = sharedTask.schedules.first {
                context.insert(schedule)
            }
        }

        if findTask(named: soloTaskTitle, in: context) == nil {
            let soloTask = makeTask(
                title: soloTaskTitle,
                scheduledDate: Date().addingTimeInterval(3 * 60 * 60),
                category: .grooming,
                cats: [primaryCat],
                caregiver: caregiver
            )
            context.insert(soloTask)
            if let schedule = soloTask.schedules.first {
                context.insert(schedule)
            }
        }
    }

    @discardableResult
    private static func secondTestCatIfNeeded(in context: ModelContext) -> Cat {
        let existingCats = cats(in: context)
        if let existingCat = existingCats.first(where: { $0.name == uiTestSecondCatName }) {
            return existingCat
        }

        let cat = Cat(name: uiTestSecondCatName, gender: .unknown)
        context.insert(cat)
        return cat
    }

    private static func fixtureTitle(for scenario: UITestSeedScenario) -> String? {
        switch scenario {
        case .singleCat:
            return nil
        case .basicDetails:
            return nil
        case .pendingTask:
            return pendingTaskTitle
        case .overdueTask:
            return overdueTaskTitle
        case .historyCompletion:
            return completedTaskTitle
        case .sharedTaskCatDeletion:
            return nil
        case .longTaskList:
            return nil
        }
    }

    private static func findTask(named title: String, in context: ModelContext) -> CareTask? {
        tasks(in: context).first(where: { $0.title == title })
    }

    private static func tasks(in context: ModelContext) -> [CareTask] {
        let descriptor = FetchDescriptor<CareTask>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func cats(in context: ModelContext) -> [Cat] {
        var descriptor = FetchDescriptor<Cat>()
        descriptor.includePendingChanges = true
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    private static func seedSecondCaregiverIfNeeded(in context: ModelContext) -> Caregiver {
        let descriptor = FetchDescriptor<Caregiver>()
        let caregivers = (try? context.fetch(descriptor)) ?? []
        if let existing = caregivers.first(where: { $0.name == uiTestSecondCaregiverName }) {
            return existing
        }

        let caregiver = Caregiver(name: uiTestSecondCaregiverName, role: .member)
        context.insert(caregiver)
        return caregiver
    }

    private static func defaultCaregiver(in context: ModelContext) -> Caregiver? {
        let descriptor = FetchDescriptor<Caregiver>()
        let caregivers = (try? context.fetch(descriptor)) ?? []
        return caregivers.first(where: \.isPrimary) ?? caregivers.first
    }
}
