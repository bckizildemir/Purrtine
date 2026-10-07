import Foundation
import Testing
@testable import CatCareCalendar

@MainActor
struct NavigationRouterTests {
    @Test(arguments: [
        (
            "catcarecalendar:///tasks?filter=overdue",
            AppRoute.tasks(taskId: nil, filter: .overdue)
        ),
        (
            "catcarecalendar:///assistant",
            AppRoute.assistant
        ),
        (
            "catcarecalendar:///task/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            AppRoute.tasks(taskId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, filter: nil)
        ),
        (
            "catcarecalendar:///history?taskId=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            AppRoute.history(taskId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        ),
        (
            "catcarecalendar:///cats/11111111-2222-3333-4444-555555555555",
            AppRoute.catDetail(UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)
        )
    ])
    func urlParsingCoversCriticalDeepLinks(rawURL: String, expectedRoute: AppRoute) throws {
        let url = try #require(URL(string: rawURL))
        let parsedRoute = try #require(AppRoute(url: url))

        #expect(parsedRoute == expectedRoute)
    }

    @Test(arguments: [
        "https://example.com/tasks",
        "catcarecalendar:///task/not-a-uuid",
        "catcarecalendar:///unknown"
    ])
    func malformedOrForeignDeepLinksAreRejected(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))

        #expect(AppRoute(url: url) == nil)
    }

    @Test
    func taskRouteClearsStaleFlagsWhileKeepingRequestedTaskSelection() {
        let sut = NavigationRouter()
        let taskId = UUID()
        sut.shouldNavigateToMyCats = true
        sut.shouldNavigateToHistory = true
        sut.shouldTriggerAddTask = true
        sut.selectedHistoryTaskId = UUID()

        sut.handle(.tasks(taskId: taskId, filter: .overdue))

        #expect(sut.selectedTab == .tasks)
        #expect(sut.selectedTaskId == taskId)
        #expect(sut.selectedTaskFilter == .overdue)
        #expect(sut.shouldNavigateToMyCats == false)
        #expect(sut.shouldNavigateToHistory == false)
        #expect(sut.shouldTriggerAddTask == false)
        #expect(sut.selectedHistoryTaskId == nil)
    }

    @Test
    func assistantRouteSelectsAssistantTabAndClearsStaleNavigationState() {
        let sut = NavigationRouter()
        sut.selectedTab = .tasks
        sut.selectedTaskId = UUID()
        sut.selectedTaskFilter = .overdue
        sut.shouldNavigateToMyCats = true
        sut.shouldNavigateToHistory = true
        sut.shouldTriggerAddTask = true

        sut.handle(.assistant)

        #expect(sut.selectedTab == .assistant)
        #expect(sut.selectedTaskId == nil)
        #expect(sut.selectedTaskFilter == nil)
        #expect(sut.shouldNavigateToMyCats == false)
        #expect(sut.shouldNavigateToHistory == false)
        #expect(sut.shouldTriggerAddTask == false)
    }

    @Test
    func catDetailRouteClearsTaskSelectionAndAppendsNavigationPath() {
        let sut = NavigationRouter()
        sut.selectedTab = .tasks
        sut.selectedTaskId = UUID()
        sut.selectedTaskFilter = .today
        sut.shouldNavigateToMyCats = true
        sut.shouldNavigateToHistory = true
        sut.shouldTriggerAddTask = true
        let catId = UUID()

        sut.handle(.catDetail(catId))

        #expect(sut.selectedTab == .home)
        #expect(sut.selectedTaskId == nil)
        #expect(sut.selectedTaskFilter == nil)
        #expect(sut.shouldNavigateToMyCats == false)
        #expect(sut.shouldNavigateToHistory == false)
        #expect(sut.shouldTriggerAddTask == false)
        #expect(sut.path.count == 1)
    }

    @Test
    func historyRouteScopesSelectedTaskAndClearsOtherNavigationState() {
        let sut = NavigationRouter()
        let taskId = UUID()
        sut.selectedTab = .tasks
        sut.selectedTaskId = UUID()
        sut.selectedTaskFilter = .overdue
        sut.shouldNavigateToMyCats = true
        sut.shouldTriggerAddTask = true

        sut.handle(.history(taskId: taskId))

        #expect(sut.selectedTab == .settings)
        #expect(sut.shouldNavigateToHistory)
        #expect(sut.shouldNavigateToMyCats == false)
        #expect(sut.shouldTriggerAddTask == false)
        #expect(sut.selectedHistoryTaskId == taskId)
        #expect(sut.selectedTaskId == nil)
        #expect(sut.selectedTaskFilter == nil)
    }
}
