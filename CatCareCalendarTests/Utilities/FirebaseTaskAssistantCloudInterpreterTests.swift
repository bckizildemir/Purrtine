import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

/// The anonymous Firebase sign-in, and with it the SDK configuration, is deferred to the first
/// consented cloud call (#12). These tests pin the seam: the sign-in closure the adapter owns.
/// Nothing here reaches Firebase.
@MainActor
struct FirebaseTaskAssistantCloudInterpreterTests {
    @MainActor
    private final class SignInSpy {
        var callCount = 0
        var error: (any Error)?

        func signIn() async throws {
            callCount += 1
            if let error { throw error }
        }
    }

    private struct SignInFailure: Error {}

    private func makeDefaults(consentGranted: Bool) throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "FirebaseTaskAssistantCloudInterpreterTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(consentGranted, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)
        return (defaults, suiteName)
    }

    @Test
    func interpretSignsInFirstAndSurfacesAFailureAsTheCallsError() async {
        let spy = SignInSpy()
        spy.error = SignInFailure()
        let sut = FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() })

        await #expect(throws: SignInFailure.self) {
            _ = try await sut.interpret(text: "x", tasks: [], referenceDate: Date())
        }

        #expect(spy.callCount == 1)
    }

    @Test
    func defaultSignInDoesNotReachFirebaseInTheUnitTestHost() async {
        await #expect(throws: FirebaseBootstrapper.SignInError.cloudServicesDisabled) {
            try await FirebaseBootstrapper.ensureSignedInAnonymously()
        }

        await #expect(throws: FirebaseBootstrapper.SignInError.cloudServicesDisabled) {
            _ = try await FirebaseTaskAssistantCloudInterpreter()
                .interpret(text: "x", tasks: [], referenceDate: Date())
        }
    }

    @Test
    func viewModelWithoutConsentNeverSignsIn() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let task = CareTask(title: "Feed Luna", category: .feeding)
        container.mainContext.insert(task)
        let spy = SignInSpy()
        let (defaults, suiteName) = try makeDefaults(consentGranted: false)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sut = TaskAssistantViewModel(
            cloudInterpreter: FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() }),
            userDefaults: defaults
        )
        sut.draftText = "this phrase matches nothing heuristically"

        await sut.sendCurrentDraft(tasks: [task])

        #expect(spy.callCount == 0)
    }

    @Test
    func viewModelWithConsentSignsInOnTheCloudCall() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let task = CareTask(title: "Feed Luna", category: .feeding)
        container.mainContext.insert(task)
        let spy = SignInSpy()
        spy.error = SignInFailure()
        let (defaults, suiteName) = try makeDefaults(consentGranted: true)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sut = TaskAssistantViewModel(
            cloudInterpreter: FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() }),
            userDefaults: defaults
        )
        sut.draftText = "this phrase matches nothing heuristically"

        await sut.sendCurrentDraft(tasks: [task])

        #expect(spy.callCount == 1)
        // A sign-in failure behaves like any cloud failure: the heuristic answer stays.
        #expect(sut.messages.last?.text == String(localized: .taskAssistantNoMatch))
        #expect(sut.isProcessing == false)
    }
}
