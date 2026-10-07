import Foundation
@testable import CatCareCalendar

@MainActor
final class FakeSpeechRecognitionService: SpeechRecognitionServicing {
    var grantsPermission = true
    var startError: SpeechRecognitionServiceError?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    private var onUpdate: (@MainActor @Sendable (String, Bool) -> Void)?
    private var onFailure: (@MainActor @Sendable () -> Void)?

    func requestPermissions() async -> Bool {
        grantsPermission
    }

    func startRecording(
        onUpdate: @escaping @MainActor @Sendable (String, Bool) -> Void,
        onFailure: @escaping @MainActor @Sendable () -> Void
    ) throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        self.onUpdate = onUpdate
        self.onFailure = onFailure
    }

    func stopRecording() {
        stopCallCount += 1
    }

    func emitTranscript(_ text: String, isFinal: Bool) {
        onUpdate?(text, isFinal)
    }

    func emitFailure() {
        onFailure?()
    }
}
