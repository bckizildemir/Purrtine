import AVFoundation
import Speech

@MainActor
final class SpeechRecognitionService: SpeechRecognitionServicing {
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hasInstalledTap = false

    init() {
        self.recognizer = SFSpeechRecognizer()
    }

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func startRecording(
        onUpdate: @escaping @MainActor @Sendable (String, Bool) -> Void,
        onFailure: @escaping @MainActor @Sendable () -> Void
    ) throws {
        guard !audioEngine.isRunning, task == nil, hasInstalledTap == false else {
            throw SpeechRecognitionServiceError.recordingAlreadyActive
        }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionServiceError.recognizerUnavailable
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else {
            throw SpeechRecognitionServiceError.recognizerUnavailable
        }
        request.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            cleanupRecordingState()
            throw SpeechRecognitionServiceError.audioSessionSetupFailed
        }

        // The engine graph is built lazily against whatever format was current at
        // AVAudioEngine init time, which predates the .record session activation above.
        // Resetting forces it to re-negotiate against the now-active session's hardware
        // format; skipping this can hand installTap a 0 Hz format and crash uncatchably.
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            cleanupRecordingState()
            throw SpeechRecognitionServiceError.audioSessionSetupFailed
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanupRecordingState()
            throw SpeechRecognitionServiceError.audioEngineStartFailed
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let didFail = result == nil && error != nil

            Task { @MainActor [weak self] in
                guard let self else { return }

                if let transcript {
                    onUpdate(transcript, isFinal)
                    if isFinal {
                        stopRecording()
                    }
                } else if didFail {
                    stopRecording()
                    onFailure()
                }
            }
        }
    }

    func stopRecording() {
        cleanupRecordingState()
    }

    private func cleanupRecordingState() {
        guard hasInstalledTap || audioEngine.isRunning || task != nil || request != nil else { return }

        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
