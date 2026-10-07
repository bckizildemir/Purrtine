import Foundation

@MainActor
protocol SpeechRecognitionServicing: AnyObject {
    func requestPermissions() async -> Bool

    func startRecording(
        onUpdate: @escaping @MainActor @Sendable (String, Bool) -> Void,
        onFailure: @escaping @MainActor @Sendable () -> Void
    ) throws

    func stopRecording()
}
