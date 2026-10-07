import Foundation

enum SpeechRecognitionServiceError: Error, Equatable {
    case recognizerUnavailable
    case recordingAlreadyActive
    case audioSessionSetupFailed
    case audioEngineStartFailed
}
