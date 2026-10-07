import Foundation
import Testing
@testable import CatCareCalendar

/// `OnboardingManager` is `@MainActor`, so the suite is too. This matches
/// `TaskAssistantCloudInterpreterTests`, which already tests a main-actor type
/// the same way.
@MainActor
struct OnboardingManagerTests {
    @Test
    func initializesCompletionStateFromInjectedDefaults() throws {
        let suiteName = suiteName()
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        suite.set(true, forKey: "hasCompletedOnboarding")

        let sut = OnboardingManager(userDefaults: suite)

        #expect(sut.hasCompletedOnboarding == true)
    }

    @Test
    func completingOnboardingPersistsCompletionState() throws {
        let suiteName = suiteName()
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let sut = OnboardingManager(userDefaults: suite)

        sut.completeOnboarding()

        #expect(sut.hasCompletedOnboarding == true)
        #expect(suite.bool(forKey: "hasCompletedOnboarding") == true)
    }

    @Test
    func resetOnboardingClearsProgressAndTemporaryState() throws {
        let suiteName = suiteName()
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let sut = OnboardingManager(userDefaults: suite)
        sut.completeOnboarding()
        sut.currentStep = .taskSetup
        sut.tempCatData.name = "Mochi"
        sut.tempCatData.age = 2
        sut.selectedTasks = [.feeding, .litterBox]

        sut.resetOnboarding()

        #expect(sut.hasCompletedOnboarding == false)
        #expect(suite.bool(forKey: "hasCompletedOnboarding") == false)
        #expect(sut.currentStep == .welcome)
        #expect(sut.tempCatData.name.isEmpty)
        #expect(sut.tempCatData.age == nil)
        #expect(sut.selectedTasks.isEmpty)
    }

    private func suiteName() -> String {
        "OnboardingManagerTests-\(UUID().uuidString)"
    }
}
