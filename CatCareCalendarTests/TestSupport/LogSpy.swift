import Synchronization

/// Records what a writer logged.
final class LogSpy: Sendable {
    private let recorded = Mutex<[String]>([])

    var messages: [String] {
        recorded.withLock { $0 }
    }

    func record(_ message: String) {
        recorded.withLock { $0.append(message) }
    }
}
