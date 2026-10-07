#if DEBUG
import Foundation
import SwiftData

@MainActor
enum PreviewData {
    private static var cachedContainers: [PreviewScenario: ModelContainer] = [:]

    static let userDefaults: UserDefaults = {
        let suiteName = "com.berkecankizildemir.CatCareCalendar.preview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }()

    static let notificationManager = NotificationManager(
        notificationCenter: PreviewUserNotificationCenterClient(),
        settingsStore: NotificationSettingsStore(userDefaults: userDefaults)
    )

    static func container(for scenario: PreviewScenario) -> ModelContainer? {
        if let cachedContainer = cachedContainers[scenario] {
            return cachedContainer
        }

        guard let container = try? makeContainer(for: scenario) else { return nil }
        cachedContainers[scenario] = container
        return container
    }

    static func firstCat(in scenario: PreviewScenario = .standard) -> Cat? {
        guard let container = container(for: scenario) else { return nil }
        return try? container.mainContext.fetch(FetchDescriptor<Cat>()).first
    }

    static func firstTask(in scenario: PreviewScenario = .standard) -> CareTask? {
        guard let container = container(for: scenario) else { return nil }
        return try? container.mainContext.fetch(FetchDescriptor<CareTask>()).first
    }

    static func makeContainer(
        for scenario: PreviewScenario,
        referenceDate: Date = .now
    ) throws -> ModelContainer {
        // The model list lives in `CatCareSchemaV1` so previews can never drift from
        // the app's real store layout. See `AppLaunchBootstrapper.makeModelContainer`.
        let schema = CatCareSchemaV1.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CatCareMigrationPlan.self,
            configurations: configuration
        )

        try seed(scenario, in: container.mainContext, referenceDate: referenceDate)
        return container
    }

    private static func seed(
        _ scenario: PreviewScenario,
        in context: ModelContext,
        referenceDate: Date
    ) throws {
        guard scenario != .empty else { return }

        let caregiver = Caregiver(name: "Alex", role: .primary)
        let luna = Cat(
            name: "Luna",
            age: 36,
            gender: .female,
            breed: "Scottish Fold",
            weight: 4.2,
            medicalNotes: "Calm, curious, and very food-motivated."
        )
        context.insert(caregiver)
        context.insert(luna)

        guard scenario != .singleCat else {
            try context.save()
            return
        }

        let simba = Cat(
            name: "Simba",
            age: 24,
            gender: .male,
            breed: "Maine Coon",
            weight: 6.8
        )
        context.insert(simba)

        let cats = [luna, simba]
        insertTask(
            title: "Morning feeding",
            description: "Serve breakfast and refresh both bowls.",
            category: .feeding,
            iconName: "fork.knife",
            priority: .high,
            dueDate: referenceDate.addingTimeInterval(60 * 60),
            frequency: .daily,
            cats: cats,
            caregiver: caregiver,
            in: context
        )
        insertTask(
            title: "Refresh water",
            description: "Wash the fountain and add fresh water.",
            category: .water,
            iconName: "drop.fill",
            priority: .urgent,
            status: .overdue,
            dueDate: referenceDate.addingTimeInterval(-60 * 60),
            frequency: .daily,
            cats: cats,
            caregiver: caregiver,
            in: context
        )
        insertTask(
            title: "Brush Luna",
            description: "Brush gently and check for mats.",
            category: .grooming,
            iconName: "comb.fill",
            dueDate: referenceDate.addingTimeInterval(24 * 60 * 60),
            frequency: .weekly,
            cats: [luna],
            caregiver: caregiver,
            in: context
        )

        if scenario == .history || scenario == .standard {
            insertCompletedTask(
                title: "Evening medication",
                completedAt: referenceDate.addingTimeInterval(-24 * 60 * 60),
                cat: luna,
                caregiver: caregiver,
                in: context
            )
        }

        if scenario == .history {
            for dayOffset in 2...5 {
                insertCompletedTask(
                    title: "Completed care \(dayOffset)",
                    completedAt: referenceDate.addingTimeInterval(TimeInterval(-dayOffset * 24 * 60 * 60)),
                    cat: dayOffset.isMultiple(of: 2) ? luna : simba,
                    caregiver: caregiver,
                    in: context
                )
            }
        }

        if scenario == .longContent {
            luna.medicalNotes = "Luna needs a quiet feeding space, a slow transition between foods, and careful monitoring after medication. Record any appetite or behavior changes."
            insertTask(
                title: "Prepare the prescription meal and record appetite observations",
                description: "Measure the full portion, supervise the meal, and add detailed notes for the veterinary follow-up.",
                category: .health,
                iconName: "heart.text.clipboard.fill",
                priority: .high,
                dueDate: referenceDate.addingTimeInterval(2 * 60 * 60),
                cats: [luna],
                caregiver: caregiver,
                in: context
            )
        }

        try context.save()
    }

    private static func insertTask(
        title: String,
        description: String,
        category: CareTaskCategory,
        iconName: String,
        priority: CareTaskPriority = .medium,
        status: CareTaskStatus = .pending,
        dueDate: Date,
        frequency: CareTaskFrequency = .once,
        cats: [Cat],
        caregiver: Caregiver,
        in context: ModelContext
    ) {
        let task = CareTask(
            title: title,
            description: description,
            category: category,
            iconName: iconName,
            priority: priority,
            status: status
        )
        let schedule = CareTaskSchedule(
            scheduledDate: dueDate,
            scheduledTime: dueDate,
            frequency: frequency,
            reminderMinutes: 15
        )
        task.assignedCats = cats
        task.assignedCaregiver = caregiver
        task.schedules = [schedule]
        schedule.task = task
        context.insert(task)
        context.insert(schedule)
    }

    private static func insertCompletedTask(
        title: String,
        completedAt: Date,
        cat: Cat,
        caregiver: Caregiver,
        in context: ModelContext
    ) {
        let task = CareTask(
            title: title,
            description: "Completed preview task",
            category: .medication,
            iconName: "pills.fill",
            priority: .high,
            status: .completed
        )
        let schedule = CareTaskSchedule(
            scheduledDate: completedAt,
            scheduledTime: completedAt
        )
        let completion = CareTaskCompletion(
            completedAt: completedAt,
            completedForDate: completedAt,
            notes: "Everything went smoothly.",
            wasOnTime: true
        )
        task.assignedCats = [cat]
        task.assignedCaregiver = caregiver
        task.schedules = [schedule]
        task.completions = [completion]
        schedule.task = task
        completion.task = task
        completion.cats = [cat]
        completion.caregiver = caregiver
        context.insert(task)
        context.insert(schedule)
        context.insert(completion)
    }
}
#endif
