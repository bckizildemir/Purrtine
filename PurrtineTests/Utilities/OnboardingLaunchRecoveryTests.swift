import Foundation
import SwiftData
import Testing
@testable import Purrtine

/// Issue #140: a kill between the first onboarding commit and `completeOnboarding()` left a cat in
/// the store with the flag still false, so the next launch showed onboarding again and a second
/// finish saved a second cat. The store is the truth at launch.
@MainActor
struct OnboardingLaunchRecoveryTests {
    private struct ProcessKilledError: Error {}

    /// Commits the way the real writer does, then never gets to return: the process died.
    private final class CommitThenDieWriter: CareTaskWriting {
        func save(_ task: CareTask, in context: ModelContext) async throws {
            try context.save()
            throw ProcessKilledError()
        }

        func delete(_ task: CareTask, in context: ModelContext) async throws {}

        func complete(
            _ task: CareTask,
            with input: CareTaskCompletionInput,
            in context: ModelContext
        ) async throws {}

        func snooze(_ task: CareTask, minutes: Int) async throws {}

        func refreshReminders(for taskIds: [UUID], in context: ModelContext) async throws {}
    }

    @Test
    func savedCatWithFlagFalseCompletesOnboardingAtLaunch() throws {
        let (suite, cleanup) = try makeSuite()
        defer { cleanup() }
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        container.mainContext.insert(Cat(name: "Mochi", gender: .unknown))
        try container.mainContext.save()
        let sut = OnboardingManager(userDefaults: suite)
        #expect(sut.hasCompletedOnboarding == false)

        sut.completeIfStoreHoldsCat(in: container.mainContext)

        #expect(sut.hasCompletedOnboarding == true)
        #expect(suite.bool(forKey: "hasCompletedOnboarding") == true)
    }

    @Test
    func emptyStoreWithFlagFalseStillShowsOnboarding() throws {
        let (suite, cleanup) = try makeSuite()
        defer { cleanup() }
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let sut = OnboardingManager(userDefaults: suite)

        sut.completeIfStoreHoldsCat(in: container.mainContext)

        #expect(sut.hasCompletedOnboarding == false)
        #expect(suite.bool(forKey: "hasCompletedOnboarding") == false)
    }

    @Test
    func completedFlagStaysCompletedWithEmptyStore() throws {
        let (suite, cleanup) = try makeSuite()
        defer { cleanup() }
        suite.set(true, forKey: "hasCompletedOnboarding")
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let sut = OnboardingManager(userDefaults: suite)

        sut.completeIfStoreHoldsCat(in: container.mainContext)

        #expect(sut.hasCompletedOnboarding == true)
    }

    @Test
    func killAfterFirstCommitRelaunchesOnHomeAndKeepsOneCat() async throws {
        let (suite, cleanup) = try makeSuite()
        defer { cleanup() }
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: container.mainContext)

        // Run 1: the commit lands, the process dies before `completeOnboarding()`.
        let firstRun = OnboardingManager(userDefaults: suite)
        var tempData = TempCatData()
        tempData.name = "Mochi"
        let builder = OnboardingDataBuilder(taskWriter: CommitThenDieWriter())
        var didDie = false
        do {
            try await builder.createCatAndTasks(
                from: tempData,
                selectedTasks: [.feeding],
                in: container.mainContext
            )
        } catch is ProcessKilledError {
            didDie = true
        }
        #expect(didDie)
        #expect(firstRun.hasCompletedOnboarding == false)

        // Run 2: a fresh manager on the same defaults, and the launch step on a fresh context.
        let secondRun = OnboardingManager(userDefaults: suite)
        #expect(secondRun.hasCompletedOnboarding == false)
        secondRun.completeIfStoreHoldsCat(in: ModelContext(container))

        #expect(secondRun.hasCompletedOnboarding == true)
        let cats = try ModelContext(container).fetch(FetchDescriptor<Cat>())
        #expect(cats.count == 1)
        #expect(cats.first?.name == "Mochi")
    }

    private func makeSuite() throws -> (UserDefaults, () -> Void) {
        let name = "OnboardingLaunchRecoveryTests-\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: name))
        return (suite, { suite.removePersistentDomain(forName: name) })
    }
}
