import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct AppLaunchBootstrapperTests {
    @Test(arguments: [
        (Set([UITestSeedScenario.singleCat]), true, []),
        (Set([UITestSeedScenario.basicDetails]), true, []),
        (Set([UITestSeedScenario.pendingTask]), true, ["UI Test Task"]),
        (Set([UITestSeedScenario.overdueTask]), true, ["UI Test Overdue Task"]),
        (Set([UITestSeedScenario.historyCompletion]), true, ["UI Test Completed Task"]),
        (Set([UITestSeedScenario.sharedTaskCatDeletion]), true, [])
    ])
    func seedPlanBuildsExpectedFixtures(
        scenarios: Set<UITestSeedScenario>,
        expectedSeedCat: Bool,
        expectedTitles: [String]
    ) {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let plan = AppLaunchBootstrapper.seedPlan(for: scenarios, now: now, calendar: .gregorian)

        #expect(plan.requiresSeedCat == expectedSeedCat)
        #expect(plan.taskFixtures.map(\.title) == expectedTitles)
    }

    @Test
    func seedPlanMarksCompletionFixtureAsCompletedAndInactive() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let fixture = try #require(
            AppLaunchBootstrapper.seedPlan(
                for: [.historyCompletion],
                now: now,
                calendar: .gregorian
            ).taskFixtures.first
        )

        #expect(fixture.status == .completed)
        #expect(fixture.isScheduleActive == false)
        #expect(fixture.createsCompletion)
        #expect(fixture.completionNotes == "UI seeded completion")
        #expect(fixture.scheduledDate < now)
    }

    @Test
    func seedPlanPlacesPendingAndOverdueFixturesOnOppositeSidesOfNow() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let plan = AppLaunchBootstrapper.seedPlan(
            for: [.pendingTask, .overdueTask],
            now: now,
            calendar: .gregorian
        )

        let pendingFixture = try #require(plan.taskFixtures.first(where: { $0.scenario == .pendingTask }))
        let overdueFixture = try #require(plan.taskFixtures.first(where: { $0.scenario == .overdueTask }))

        #expect(pendingFixture.status == .pending)
        #expect(pendingFixture.scheduledDate > now)
        #expect(pendingFixture.createsCompletion == false)

        #expect(overdueFixture.status == .pending)
        #expect(overdueFixture.scheduledDate < now)
        #expect(overdueFixture.createsCompletion == false)
    }

    @Test(arguments: [9, 23])
    func pendingFixtureStaysTodayAndInFutureRegardlessOfTimeOfDay(hour: Int) throws {
        // Pin the clock to a fixed hour (09:00 and 23:50) so we prove the fixture
        // never crosses midnight into `.tomorrow` — the late-in-the-day bug that
        // dropped "UI Test Task" from Home and the assistant's due-today actions.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        let startOfDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        let now = try #require(
            calendar.date(byAdding: DateComponents(hour: hour, minute: 50), to: startOfDay)
        )

        let fixture = try #require(
            AppLaunchBootstrapper.seedPlan(for: [.pendingTask], now: now, calendar: calendar)
                .taskFixtures.first
        )

        // Still pending (future), and its resolved due instant lands on *today*.
        #expect(fixture.scheduledDate > now)
        #expect(calendar.isDate(fixture.scheduledDate, inSameDayAs: now))
        let scheduledTime = try #require(fixture.scheduledTime)
        #expect(calendar.isDate(scheduledTime, inSameDayAs: now))
    }

    @Test
    func longTaskListSeedPlanProvidesScrollableFixtures() {
        let plan = AppLaunchBootstrapper.seedPlan(for: [.longTaskList])

        #expect(plan.requiresSeedCat)
        #expect(plan.taskFixtures.count == 18)
        #expect(plan.taskFixtures.first?.title == "UI Test Long Task 01")
        #expect(plan.taskFixtures.last?.title == "UI Test Long Task 18")
    }

    @Test(arguments: [
        (
            AppLaunchConfiguration(arguments: ["app", "-ui-testing", "-launch-route", "tasks"]),
            AppTab.tasks,
            false,
            false,
            false,
            nil as CareTaskFilter?
        ),
        (
            AppLaunchConfiguration(arguments: ["app", "-ui-testing", "-launch-route", "assistant"]),
            AppTab.assistant,
            false,
            false,
            false,
            nil as CareTaskFilter?
        ),
        (
            AppLaunchConfiguration(arguments: ["app", "-ui-testing", "-launch-route", "history"]),
            AppTab.settings,
            false,
            true,
            false,
            nil as CareTaskFilter?
        ),
        (
            AppLaunchConfiguration(arguments: ["app", "-ui-testing", "-launch-route", "add_task", "-launch-task-filter", "overdue"]),
            AppTab.tasks,
            false,
            false,
            true,
            .overdue as CareTaskFilter?
        )
    ])
    func applyingLaunchStateConfiguresRouter(
        configuration: AppLaunchConfiguration,
        expectedTab: AppTab,
        expectedCatsNavigation: Bool,
        expectedHistoryNavigation: Bool,
        expectedAddTaskTrigger: Bool,
        expectedFilter: CareTaskFilter?
    ) {
        let router = NavigationRouter()

        AppLaunchBootstrapper.applyLaunchStateIfNeeded(to: router, using: configuration)

        #expect(router.selectedTab == expectedTab)
        #expect(router.shouldNavigateToMyCats == expectedCatsNavigation)
        #expect(router.shouldNavigateToHistory == expectedHistoryNavigation)
        #expect(router.shouldTriggerAddTask == expectedAddTaskTrigger)
        #expect(router.selectedTaskFilter == expectedFilter)
    }

    @Test
    func seedingSharedTaskDeletionScenarioCreatesSharedAndSoloTasksAcrossTwoCats() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)

        let configuration = AppLaunchConfiguration(
            arguments: ["app", "-ui-testing", "-seed-scenario", "shared_task_cat_deletion"]
        )

        AppLaunchBootstrapper.seedInitialDataIfNeeded(in: context, using: configuration)

        let cats = try context.fetch(FetchDescriptor<Cat>())
        let tasks = try context.fetch(FetchDescriptor<CareTask>())

        let sharedTask = try #require(tasks.first(where: { $0.title == "UI Shared Task" }))
        let soloTask = try #require(tasks.first(where: { $0.title == "UI Solo Task" }))

        #expect(cats.count == 2)
        #expect(Set(cats.map(\.name)) == Set(["UI Test Cat", "UI Second Test Cat"]))
        #expect(sharedTask.assignedCats.count == 2)
        #expect(soloTask.assignedCats.map(\.name) == ["UI Test Cat"])
    }
}

private extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}
