import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

/// The anonymous Firebase sign-in is deferred to the first cloud call (#12). These tests pin
/// the seam: the sign-in closure the adapter owns. Nothing here reaches Firebase.
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

    @Test
    func buildingTheInterpreterDoesNotSignIn() {
        let spy = SignInSpy()

        _ = FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() })

        #expect(spy.callCount == 0)
    }

    @Test
    func interpretSignsInBeforeAnythingElse() async throws {
        let task = CareTask(title: "Feed Luna", category: .feeding)
        let spy = SignInSpy()
        let sut = FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() })

        // Firebase is not configured in the test host, so the call stops right after the
        // sign-in with `firebaseNotConfigured`. That error proves the sign-in came first.
        await #expect(throws: FirebaseTaskAssistantCloudInterpreter.CloudInterpreterError.self) {
            _ = try await sut.interpret(text: "x", tasks: [task], referenceDate: Date())
        }

        #expect(spy.callCount == 1)
    }

    @Test
    func signInFailureSurfacesAsTheCallsError() async {
        let spy = SignInSpy()
        spy.error = SignInFailure()
        let sut = FirebaseTaskAssistantCloudInterpreter(signIn: { try await spy.signIn() })

        await #expect(throws: SignInFailure.self) {
            _ = try await sut.interpret(text: "x", tasks: [], referenceDate: Date())
        }
    }

    @Test
    func viewModelWithoutConsentNeverSignsIn() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let task = CareTask(title: "Feed Luna", category: .feeding)
        container.mainContext.insert(task)
        let spy = SignInSpy()
        let defaults = UserDefaults(suiteName: "FirebaseTaskAssistantCloudInterpreterTests.\(UUID().uuidString)")!
        defaults.set(false, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)
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
        let defaults = UserDefaults(suiteName: "FirebaseTaskAssistantCloudInterpreterTests.\(UUID().uuidString)")!
        defaults.set(true, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)
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
